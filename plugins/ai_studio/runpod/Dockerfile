# Studio IA — RunPod Worker
#
# Les modèles sont stockés sur un Network Volume RunPod (Method 2).
# Monté en /runpod-volume, ComfyUI les détecte sous /runpod-volume/models/...
#
# Seuls les custom nodes sont baked dans l'image (impossible via network volume).

FROM runpod/worker-comfyui:5.8.5-base

# Remap model paths to match the network volume structure (runpod-slim layout)
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    pip install -r ComfyUI-KJNodes/requirements.txt && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git && \
    pip install -r ComfyUI-Easy-Use/requirements.txt && \
    git clone https://github.com/1038lab/ComfyUI-RMBG.git && \
    pip install -r ComfyUI-RMBG/requirements.txt && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    pip install -r ComfyUI-Impact-Pack/requirements.txt && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git && \
    pip install -r ComfyUI-Impact-Subpack/requirements.txt && \
    git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git
