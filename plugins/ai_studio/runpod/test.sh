#!/bin/bash
# Test de l'endpoint RunPod Studio IA — workflow CREATION
# Usage: RUNPOD_API_KEY=rpa_xxx bash test.sh [chemin/vers/image.png]
set -e

ENDPOINT_ID="r154959c428m8u"
API_KEY="${RUNPOD_API_KEY:-}"
IMAGE_PATH="${1:-}"

if [ -z "$API_KEY" ]; then
    echo "Erreur: RUNPOD_API_KEY non définie"
    echo "Usage: RUNPOD_API_KEY=rpa_xxx bash test.sh [image.png]"
    exit 1
fi

# Encode l'image source en base64 (ou utilise un pixel blanc de test si pas d'image)
if [ -n "$IMAGE_PATH" ] && [ -f "$IMAGE_PATH" ]; then
    IMAGE_B64=$(base64 -w 0 "$IMAGE_PATH")
    IMAGE_NAME=$(basename "$IMAGE_PATH")
    echo "Image source : $IMAGE_PATH"
else
    # PNG 64x64 blanc minimal pour smoke test
    IMAGE_B64="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIABQAABjE+ibYAAAAASUVORK5CYII="
    IMAGE_NAME="test.png"
    echo "Pas d'image fournie — utilisation d'un pixel de test"
fi

WORKFLOW=$(cat <<'EOF'
{
  "9":      { "class_type": "SaveImage",               "inputs": { "filename_prefix": "Flux2-Klein", "images": ["100", 0] } },
  "76":     { "class_type": "LoadImage",               "inputs": { "image": "SOURCE_IMAGE" } },
  "100":    { "class_type": "BiRefNetRMBG",            "inputs": { "model": "BiRefNet-general", "mask_blur": 0, "mask_offset": 0, "invert_output": false, "refine_foreground": true, "background": "Alpha", "background_color": "#222222", "image": ["75:65", 0] } },
  "75:61":  { "class_type": "KSamplerSelect",          "inputs": { "sampler_name": "euler" } },
  "75:64":  { "class_type": "SamplerCustomAdvanced",   "inputs": { "noise": ["75:73", 0], "guider": ["75:63", 0], "sampler": ["75:61", 0], "sigmas": ["75:62", 0], "latent_image": ["75:66", 0] } },
  "75:65":  { "class_type": "VAEDecode",               "inputs": { "samples": ["75:64", 0], "vae": ["75:72", 0] } },
  "75:73":  { "class_type": "RandomNoise",             "inputs": { "noise_seed": 42 } },
  "75:70":  { "class_type": "UNETLoader",              "inputs": { "unet_name": "flux-2-klein-base-9b-fp8.safetensors", "weight_dtype": "default" } },
  "75:71":  { "class_type": "CLIPLoader",              "inputs": { "clip_name": "qwen_3_8b_fp8mixed.safetensors", "type": "flux2", "device": "default" } },
  "75:72":  { "class_type": "VAELoader",               "inputs": { "vae_name": "flux2-vae.safetensors" } },
  "75:66":  { "class_type": "EmptyFlux2LatentImage",   "inputs": { "width": ["75:81", 0], "height": ["75:81", 1], "batch_size": 1 } },
  "75:80":  { "class_type": "ImageScaleToTotalPixels", "inputs": { "upscale_method": "lanczos", "megapixels": 1, "resolution_steps": 1, "image": ["76", 0] } },
  "75:63":  { "class_type": "CFGGuider",               "inputs": { "cfg": 1, "model": ["75:70", 0], "positive": ["75:79:77", 0], "negative": ["75:79:76", 0] } },
  "75:62":  { "class_type": "Flux2Scheduler",          "inputs": { "steps": 4, "width": ["75:81", 0], "height": ["75:81", 1] } },
  "75:74":  { "class_type": "CLIPTextEncode",          "inputs": { "text": "a young woman, anime style, white background", "clip": ["75:71", 0] } },
  "75:81":  { "class_type": "GetImageSize",            "inputs": { "image": ["75:80", 0] } },
  "75:79:76": { "class_type": "ReferenceLatent",       "inputs": { "conditioning": ["75:82", 0], "latent": ["75:79:78", 0] } },
  "75:79:78": { "class_type": "VAEEncode",             "inputs": { "pixels": ["75:80", 0], "vae": ["75:72", 0] } },
  "75:79:77": { "class_type": "ReferenceLatent",       "inputs": { "conditioning": ["75:74", 0], "latent": ["75:79:78", 0] } },
  "75:82":  { "class_type": "ConditioningZeroOut",     "inputs": { "conditioning": ["75:74", 0] } }
}
EOF
)

# Injecte le nom de l'image source dans le workflow
WORKFLOW=$(echo "$WORKFLOW" | sed "s/SOURCE_IMAGE/$IMAGE_NAME/")

PAYLOAD=$(jq -n \
    --argjson workflow "$WORKFLOW" \
    --arg image_name "$IMAGE_NAME" \
    --arg image_b64 "$IMAGE_B64" \
    '{input: {workflow: $workflow, images: [{name: $image_name, image: $image_b64}]}}')

echo ""
echo "=== Envoi du job ==="
RESPONSE=$(curl -s -X POST "https://api.runpod.ai/v2/${ENDPOINT_ID}/run" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${API_KEY}" \
    -d "$PAYLOAD")

echo "$RESPONSE" | jq .
JOB_ID=$(echo "$RESPONSE" | jq -r '.id // empty')

if [ -z "$JOB_ID" ]; then
    echo "Erreur: pas de job ID dans la réponse"
    exit 1
fi

echo ""
echo "=== Job ID: $JOB_ID — polling du statut ==="
for i in $(seq 1 30); do
    sleep 10
    STATUS=$(curl -s "https://api.runpod.ai/v2/${ENDPOINT_ID}/status/${JOB_ID}" \
        -H "Authorization: Bearer ${API_KEY}")
    STATE=$(echo "$STATUS" | jq -r '.status')
    echo "[$i] $STATE"
    if [ "$STATE" = "COMPLETED" ]; then
        echo ""
        echo "=== Succès ! ==="
        echo "$STATUS" | jq '.output'
        exit 0
    elif [ "$STATE" = "FAILED" ]; then
        echo ""
        echo "=== Echec ==="
        echo "$STATUS" | jq .
        exit 1
    fi
done

echo "Timeout — dernier statut :"
echo "$STATUS" | jq .
