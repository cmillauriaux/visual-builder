#!/bin/bash
set -e

ROOT="/workspace/ComfyUI/models"

# Civitai API token - get yours at https://civitai.com/user/account (API Keys section)
CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"
if [ -z "$CIVITAI_TOKEN" ]; then
  echo "WARNING: CIVITAI_TOKEN not set. Civitai downloads may fail."
  echo "Get a token at: https://civitai.com/user/account -> API Keys"
  echo "Usage: CIVITAI_TOKEN=your_token_here bash download_models.sh"
  echo ""
fi

# Helper: download only if file doesn't already exist
download() {
  local dest="$1"
  local url="$2"
  if [ -f "$dest" ]; then
    echo "SKIP: $(basename "$dest") already exists"
  else
    wget -c -O "$dest" "$url"
  fi
}

echo "=== Creating directories ==="
mkdir -p "$ROOT/text_encoders"
mkdir -p "$ROOT/vae"
mkdir -p "$ROOT/diffusion_models"
mkdir -p "$ROOT/checkpoints"
mkdir -p "$ROOT/loras"
mkdir -p "$ROOT/upscale_models"

echo ""
echo "=== [1/6] text_encoders/qwen_3_8b_fp8mixed.safetensors ==="
download "$ROOT/text_encoders/qwen_3_8b_fp8mixed.safetensors" \
  "https://huggingface.co/Comfy-Org/flux2-klein-9B/resolve/main/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors"

echo ""
echo "=== [2/6] vae/flux2-vae.safetensors ==="
download "$ROOT/vae/flux2-vae.safetensors" \
  "https://huggingface.co/Comfy-Org/flux2-klein-9B/resolve/main/split_files/vae/flux2-vae.safetensors"

echo ""
echo "=== [3/6] checkpoints/flux-2-klein-9b-fp8.safetensors ==="
download "$ROOT/diffusion_models/flux-2-klein-9b-fp8.safetensors" \
  "https://modelscope.cn/models/black-forest-labs/FLUX.2-klein-9b-fp8/resolve/master/flux-2-klein-9b-fp8.safetensors"

echo ""
echo "=== [4/8] ultralytics/bbox/face_yolov8m.pt ==="
mkdir -p "$ROOT/ultralytics/bbox"
download "$ROOT/ultralytics/bbox/face_yolov8m.pt" \
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt"

echo ""
echo "=== [5/8] upscale_models — ESRGAN models ==="
download "$ROOT/upscale_models/4x-UltraSharp.pth" \
  "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth"

download "$ROOT/upscale_models/4x_NMKD-Siax_200k.pth" \
  "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Siax_200k.pth"

download "$ROOT/upscale_models/RealESRGAN_x4plus.pth" \
  "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth"

download "$ROOT/upscale_models/RealESRGAN_x4plus_anime_6B.pth" \
  "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth"

echo ""
echo "=== [6/8] Installing custom nodes ==="

CUSTOM_NODES="/workspace/ComfyUI/custom_nodes"

install_node() {
  local name="$1"
  local url="$2"
  local dir="$CUSTOM_NODES/$name"
  if [ -d "$dir" ]; then
    echo "SKIP: $name already installed"
  else
    echo "Installing $name..."
    git clone "$url" "$dir"
    if [ -f "$dir/requirements.txt" ]; then
      pip install -r "$dir/requirements.txt"
    fi
  fi
}

install_node "ComfyUI-Manager" "https://github.com/ltdrdata/ComfyUI-Manager.git"
install_node "ComfyUI_IPAdapter_plus" "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
install_node "ComfyUI-Impact-Pack" "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
install_node "ComfyUI-Impact-Subpack" "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git"
install_node "ComfyUI-Easy-Use" "https://github.com/yolain/ComfyUI-Easy-Use.git"
install_node "ComfyUI-KJNodes" "https://github.com/kijai/ComfyUI-KJNodes.git"
install_node "ComfyUI-RMBG" "https://github.com/1038lab/ComfyUI-RMBG.git"
# Required for the Upscale tab (Ultimate SD Upscale tiling node)
install_node "ComfyUI_UltimateSDUpscale" "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"

echo ""
echo "=== All downloads complete! ==="
ls -lh "$ROOT/text_encoders/"
ls -lh "$ROOT/vae/"
ls -lh "$ROOT/diffusion_models/"
ls -lh "$ROOT/upscale_models/"
ls -lh "$ROOT/ultralytics/bbox/"
