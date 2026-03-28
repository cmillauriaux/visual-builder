extends Node

## Client HTTP pour ComfyUI. Gère upload, prompt, polling et download.

const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")

signal generation_completed(image: Image)
signal generation_failed(error: String)
signal generation_progress(status: String)

enum WorkflowType { CREATION = 0, EXPRESSION = 1, UPSCALE = 2, HIRES = 3, EXPRESSION_FACE_DETAILER = 4, EXPRESSION_LIVE_PORTRAIT = 5 }

var _generating: bool = false
var _prompt_id: String = ""
var _config: RefCounted = null
var _poll_timer: Timer = null
var _cancelled: bool = false
var _remove_background: bool = true
var _cfg: float = 1.0
var _steps: int = 4
var _denoise: float = 0.5
var _workflow_type: int = WorkflowType.CREATION
var _negative_prompt: String = ""
var _face_box_size: int = 80
var _upscale_model_name: String = "4x-UltraSharp.pth"
var _upscale_tile_size: int = 512
var _upscale_target_w: int = 0
var _upscale_target_h: int = 0
var _megapixels: float = 1.0
var _loras: Array = []

# --- Workflow template (Flux 2 Klein + BiRefNet) ---
# Reproduit exactement Edit_Image_Transparent_API.json
# Paramètres dynamiques : 76.inputs.image, 75:74.inputs.text, 75:73.inputs.noise_seed

const WORKFLOW_TEMPLATE: Dictionary = {
	"9": {
		"class_type": "SaveImage",
		"inputs": {
			"filename_prefix": "Flux2-Klein",
			"images": ["100", 0]
		}
	},
	"76": {
		"class_type": "LoadImage",
		"inputs": {
			"image": ""
		}
	},
	"81": {
		"class_type": "LoadImage",
		"inputs": {
			"image": "comfy_logo_blue.png"
		}
	},
	"100": {
		"class_type": "BiRefNetRMBG",
		"inputs": {
			"model": "BiRefNet-general",
			"mask_blur": 0,
			"mask_offset": 0,
			"invert_output": false,
			"refine_foreground": true,
			"background": "Alpha",
			"background_color": "#222222",
			"image": ["75:65", 0]
		}
	},
	"75:61": {
		"class_type": "KSamplerSelect",
		"inputs": {
			"sampler_name": "euler"
		}
	},
	"75:64": {
		"class_type": "SamplerCustomAdvanced",
		"inputs": {
			"noise": ["75:73", 0],
			"guider": ["75:63", 0],
			"sampler": ["75:61", 0],
			"sigmas": ["75:62", 0],
			"latent_image": ["75:66", 0]
		}
	},
	"75:65": {
		"class_type": "VAEDecode",
		"inputs": {
			"samples": ["75:64", 0],
			"vae": ["75:72", 0]
		}
	},
	"75:73": {
		"class_type": "RandomNoise",
		"inputs": {
			"noise_seed": 0
		}
	},
	"75:70": {
		"class_type": "UNETLoader",
		"inputs": {
			"unet_name": "flux-2-klein-base-9b-fp8.safetensors",
			"weight_dtype": "default"
		}
	},
	"75:71": {
		"class_type": "CLIPLoader",
		"inputs": {
			"clip_name": "qwen_3_8b_fp8mixed.safetensors",
			"type": "flux2",
			"device": "default"
		}
	},
	"75:72": {
		"class_type": "VAELoader",
		"inputs": {
			"vae_name": "flux2-vae.safetensors"
		}
	},
	"75:66": {
		"class_type": "EmptyFlux2LatentImage",
		"inputs": {
			"width": ["75:81", 0],
			"height": ["75:81", 1],
			"batch_size": 1
		}
	},
	"75:80": {
		"class_type": "ImageScaleToTotalPixels",
		"inputs": {
			"upscale_method": "lanczos",
			"megapixels": 1,
			"resolution_steps": 1,
			"image": ["76", 0]
		}
	},
	"75:63": {
		"class_type": "CFGGuider",
		"inputs": {
			"cfg": 1,
			"model": ["75:70", 0],
			"positive": ["75:79:77", 0],
			"negative": ["75:79:76", 0]
		}
	},
	"75:62": {
		"class_type": "Flux2Scheduler",
		"inputs": {
			"steps": 4,
			"width": ["75:81", 0],
			"height": ["75:81", 1]
		}
	},
	"75:74": {
		"class_type": "CLIPTextEncode",
		"inputs": {
			"text": "",
			"clip": ["75:71", 0]
		}
	},
	"75:81": {
		"class_type": "GetImageSize",
		"inputs": {
			"image": ["75:80", 0]
		}
	},
	"75:79:76": {
		"class_type": "ReferenceLatent",
		"inputs": {
			"conditioning": ["75:82", 0],
			"latent": ["75:79:78", 0]
		}
	},
	"75:79:78": {
		"class_type": "VAEEncode",
		"inputs": {
			"pixels": ["75:80", 0],
			"vae": ["75:72", 0]
		}
	},
	"75:79:77": {
		"class_type": "ReferenceLatent",
		"inputs": {
			"conditioning": ["75:74", 0],
			"latent": ["75:79:78", 0]
		}
	},
	"75:82": {
		"class_type": "ConditioningZeroOut",
		"inputs": {
			"conditioning": ["75:74", 0]
		}
	}
}

# --- Expression workflow template (Flux 2 Klein + face detect/mask/composite + BiRefNet) ---
# Même base de génération que Création (noeuds 75:xx) + détection de visage YOLO +
# masquage + composition sur l'original pour ne modifier que le visage.
# Paramètres dynamiques : 76.inputs.image, 75:74.inputs.text, 75:73.inputs.noise_seed,
#                         75:63.inputs.cfg, 75:62.inputs.steps

const EXPRESSION_WORKFLOW_TEMPLATE: Dictionary = {
	"9": {
		"class_type": "SaveImage",
		"inputs": {
			"filename_prefix": "ExpressionEdit",
			"images": ["106", 0]
		}
	},
	"76": {
		"class_type": "LoadImage",
		"inputs": {
			"image": ""
		}
	},
	"99": {
		"class_type": "UltralyticsDetectorProvider",
		"inputs": {
			"model_name": "bbox/face_yolov8m.pt"
		}
	},
	"100": {
		"class_type": "BboxDetectorCombined_v2",
		"inputs": {
			"threshold": 0.4,
			"dilation": 80,
			"bbox_detector": ["99", 0],
			"image": ["76", 0]
		}
	},
	"101": {
		"class_type": "GrowMask",
		"inputs": {
			"expand": 80,
			"tapered_corners": true,
			"mask": ["100", 0]
		}
	},
	"102": {
		"class_type": "ImpactGaussianBlurMask",
		"inputs": {
			"kernel_size": 51,
			"sigma": 25,
			"mask": ["101", 0]
		}
	},
	"103": {
		"class_type": "ImageCompositeMasked",
		"inputs": {
			"x": 0,
			"y": 0,
			"resize_source": true,
			"destination": ["76", 0],
			"source": ["75:65", 0],
			"mask": ["102", 0]
		}
	},
	"106": {
		"class_type": "BiRefNetRMBG",
		"inputs": {
			"model": "BiRefNet-general",
			"mask_blur": 0,
			"mask_offset": 0,
			"invert_output": false,
			"refine_foreground": true,
			"background": "Alpha",
			"background_color": "#222222",
			"image": ["103", 0]
		}
	},
	"75:61": {
		"class_type": "KSamplerSelect",
		"inputs": {
			"sampler_name": "euler"
		}
	},
	"75:64": {
		"class_type": "SamplerCustomAdvanced",
		"inputs": {
			"noise": ["75:73", 0],
			"guider": ["75:63", 0],
			"sampler": ["75:61", 0],
			"sigmas": ["75:62", 0],
			"latent_image": ["75:66", 0]
		}
	},
	"75:65": {
		"class_type": "VAEDecode",
		"inputs": {
			"samples": ["75:64", 0],
			"vae": ["75:72", 0]
		}
	},
	"75:73": {
		"class_type": "RandomNoise",
		"inputs": {
			"noise_seed": 0
		}
	},
	"75:70": {
		"class_type": "UNETLoader",
		"inputs": {
			"unet_name": "flux-2-klein-base-9b-fp8.safetensors",
			"weight_dtype": "default"
		}
	},
	"75:71": {
		"class_type": "CLIPLoader",
		"inputs": {
			"clip_name": "qwen_3_8b_fp8mixed.safetensors",
			"type": "flux2",
			"device": "default"
		}
	},
	"75:72": {
		"class_type": "VAELoader",
		"inputs": {
			"vae_name": "flux2-vae.safetensors"
		}
	},
	"75:66": {
		"class_type": "EmptyFlux2LatentImage",
		"inputs": {
			"width": ["75:81", 0],
			"height": ["75:81", 1],
			"batch_size": 1
		}
	},
	"75:80": {
		"class_type": "ImageScaleToTotalPixels",
		"inputs": {
			"upscale_method": "lanczos",
			"megapixels": 1,
			"resolution_steps": 1,
			"image": ["76", 0]
		}
	},
	"75:63": {
		"class_type": "CFGGuider",
		"inputs": {
			"cfg": 1,
			"model": ["75:70", 0],
			"positive": ["75:79:77", 0],
			"negative": ["75:79:76", 0]
		}
	},
	"75:62": {
		"class_type": "Flux2Scheduler",
		"inputs": {
			"steps": 4,
			"width": ["75:81", 0],
			"height": ["75:81", 1]
		}
	},
	"75:74": {
		"class_type": "CLIPTextEncode",
		"inputs": {
			"text": "",
			"clip": ["75:71", 0]
		}
	},
	"75:81": {
		"class_type": "GetImageSize",
		"inputs": {
			"image": ["75:80", 0]
		}
	},
	"75:79:76": {
		"class_type": "ReferenceLatent",
		"inputs": {
			"conditioning": ["75:82", 0],
			"latent": ["75:79:78", 0]
		}
	},
	"75:79:78": {
		"class_type": "VAEEncode",
		"inputs": {
			"pixels": ["75:80", 0],
			"vae": ["75:72", 0]
		}
	},
	"75:79:77": {
		"class_type": "ReferenceLatent",
		"inputs": {
			"conditioning": ["75:74", 0],
			"latent": ["75:79:78", 0]
		}
	},
	"75:82": {
		"class_type": "ConditioningZeroOut",
		"inputs": {
			"conditioning": ["75:74", 0]
		}
	}
}

# --- FaceDetailer workflow template (Impact Pack FaceDetailer + Flux 2 Klein) ---
# Détecte le visage, crop à guide_size, génère en img2img, recolle, supprime le fond.
# Paramètres dynamiques : 76.inputs.image, 75:74.inputs.text, 200.inputs.seed,
#                         200.inputs.cfg, 200.inputs.steps, 200.inputs.denoise,
#                         200.inputs.bbox_dilation
# Prérequis ComfyUI : ComfyUI-Impact-Pack (FaceDetailer, UltralyticsDetectorProvider)
# Note : FaceDetailer utilise KSampler en interne (euler + scheduler simple, CFG bas)

const FACE_DETAILER_WORKFLOW_TEMPLATE: Dictionary = {
	"9": {
		"class_type": "SaveImage",
		"inputs": {
			"filename_prefix": "FaceDetailer",
			"images": ["106", 0]
		}
	},
	"76": {
		"class_type": "LoadImage",
		"inputs": {
			"image": ""
		}
	},
	"99": {
		"class_type": "UltralyticsDetectorProvider",
		"inputs": {
			"model_name": "bbox/face_yolov8m.pt"
		}
	},
	"75:70": {
		"class_type": "UNETLoader",
		"inputs": {
			"unet_name": "flux-2-klein-base-9b-fp8.safetensors",
			"weight_dtype": "default"
		}
	},
	"75:71": {
		"class_type": "CLIPLoader",
		"inputs": {
			"clip_name": "qwen_3_8b_fp8mixed.safetensors",
			"type": "flux2",
			"device": "default"
		}
	},
	"75:72": {
		"class_type": "VAELoader",
		"inputs": {
			"vae_name": "flux2-vae.safetensors"
		}
	},
	"75:74": {
		"class_type": "CLIPTextEncode",
		"inputs": {
			"text": "",
			"clip": ["75:71", 0]
		}
	},
	"75:82": {
		"class_type": "ConditioningZeroOut",
		"inputs": {
			"conditioning": ["75:74", 0]
		}
	},
	"200": {
		"class_type": "FaceDetailer",
		"inputs": {
			"image": ["76", 0],
			"model": ["75:70", 0],
			"clip": ["75:71", 0],
			"vae": ["75:72", 0],
			"guide_size": 512,
			"guide_size_for": "bbox",
			"max_size": 1024,
			"seed": 0,
			"steps": 4,
			"cfg": 1.0,
			"sampler_name": "euler",
			"scheduler": "simple",
			"positive": ["75:74", 0],
			"negative": ["75:82", 0],
			"denoise": 0.5,
			"feather": 20,
			"noise_mask": true,
			"force_inpaint": true,
			"bbox_threshold": 0.4,
			"bbox_dilation": 80,
			"bbox_crop_factor": 3.0,
			"sam_detection_hint": "center-1",
			"sam_dilation": 0,
			"sam_threshold": 0.93,
			"sam_bbox_expansion": 0,
			"sam_mask_hint_threshold": 0.7,
			"sam_mask_hint_use_negative": "False",
			"drop_size": 10,
			"provider": "CPU",
			"device_id": 0,
			"bbox_detector": ["99", 0],
			"wildcard": "",
			"cycle": 1
		}
	},
	"106": {
		"class_type": "BiRefNetRMBG",
		"inputs": {
			"model": "BiRefNet-general",
			"mask_blur": 0,
			"mask_offset": 0,
			"invert_output": false,
			"refine_foreground": true,
			"background": "Alpha",
			"background_color": "#222222",
			"image": ["200", 0]
		}
	}
}

# --- Upscale workflow template (ESRGAN + Ultimate SD Upscale + Flux 2 Klein) ---
# Paramètres dynamiques : 1.inputs.image, 2.inputs.model_name,
#                         4.inputs.width, 4.inputs.height,
#                         13.inputs.text, 20.inputs.denoise, 20.inputs.seed,
#                         20.inputs.tile_width, 20.inputs.tile_height

const UPSCALE_WORKFLOW_TEMPLATE: Dictionary = {
	"1": {
		"class_type": "LoadImage",
		"inputs": {
			"image": ""
		}
	},
	"2": {
		"class_type": "UpscaleModelLoader",
		"inputs": {
			"model_name": "4x-UltraSharp.pth"
		}
	},
	"3": {
		"class_type": "ImageUpscaleWithModel",
		"inputs": {
			"upscale_model": ["2", 0],
			"image": ["1", 0]
		}
	},
	"4": {
		"class_type": "ImageScale",
		"inputs": {
			"image": ["3", 0],
			"upscale_method": "lanczos",
			"width": 0,
			"height": 0,
			"crop": "disabled"
		}
	},
	"75:70": {
		"class_type": "UNETLoader",
		"inputs": {
			"unet_name": "flux-2-klein-base-9b-fp8.safetensors",
			"weight_dtype": "default"
		}
	},
	"75:71": {
		"class_type": "CLIPLoader",
		"inputs": {
			"clip_name": "qwen_3_8b_fp8mixed.safetensors",
			"type": "flux2",
			"device": "default"
		}
	},
	"75:72": {
		"class_type": "VAELoader",
		"inputs": {
			"vae_name": "flux2-vae.safetensors"
		}
	},
	"13": {
		"class_type": "CLIPTextEncode",
		"inputs": {
			"text": "",
			"clip": ["75:71", 0]
		}
	},
	"14": {
		"class_type": "ConditioningZeroOut",
		"inputs": {
			"conditioning": ["13", 0]
		}
	},
	"20": {
		"class_type": "UltimateSDUpscale",
		"inputs": {
			"upscale_by": 1.0,
			"seed": 0,
			"steps": 4,
			"cfg": 1.0,
			"sampler_name": "euler",
			"scheduler": "simple",
			"denoise": 0.35,
			"mode_type": "Linear",
			"tile_width": 512,
			"tile_height": 512,
			"mask_blur": 8,
			"tile_padding": 32,
			"seam_fix_mode": "None",
			"seam_fix_denoise": 0.35,
			"seam_fix_width": 64,
			"seam_fix_mask_blur": 8,
			"seam_fix_padding": 16,
			"force_uniform_tiles": true,
			"tiled_decode": false,
			"image": ["4", 0],
			"model": ["75:70", 0],
			"positive": ["13", 0],
			"negative": ["14", 0],
			"vae": ["75:72", 0]
		}
	},
	"9": {
		"class_type": "SaveImage",
		"inputs": {
			"filename_prefix": "Upscale",
			"images": ["20", 0]
		}
	}
}

# --- HiRes Fix workflow template (Flux 2 Klein, img2img full-image, même résolution) ---
# Identique au workflow Expression SANS les noeuds de détection de visage (99,100,101,102,103,106).
# La sortie SaveImage pointe directement sur VAEDecode (75:65) — pas de BiRefNet.
# Paramètres dynamiques : 76.inputs.image, 75:74.inputs.text, 75:73.inputs.noise_seed,
#                         75:63.inputs.cfg, 75:62.inputs.steps + SplitSigmas calculé
const HIRES_WORKFLOW_TEMPLATE: Dictionary = {
	"9": {
		"class_type": "SaveImage",
		"inputs": {
			"filename_prefix": "HiResFix",
			"images": ["75:65", 0]
		}
	},
	"76": {
		"class_type": "LoadImage",
		"inputs": {
			"image": ""
		}
	},
	"75:61": {
		"class_type": "KSamplerSelect",
		"inputs": {
			"sampler_name": "euler"
		}
	},
	"75:64": {
		"class_type": "SamplerCustomAdvanced",
		"inputs": {
			"noise": ["75:73", 0],
			"guider": ["75:63", 0],
			"sampler": ["75:61", 0],
			"sigmas": ["75:62", 0],
			"latent_image": ["75:66", 0]
		}
	},
	"75:65": {
		"class_type": "VAEDecode",
		"inputs": {
			"samples": ["75:64", 0],
			"vae": ["75:72", 0]
		}
	},
	"75:73": {
		"class_type": "RandomNoise",
		"inputs": {
			"noise_seed": 0
		}
	},
	"75:70": {
		"class_type": "UNETLoader",
		"inputs": {
			"unet_name": "flux-2-klein-base-9b-fp8.safetensors",
			"weight_dtype": "default"
		}
	},
	"75:71": {
		"class_type": "CLIPLoader",
		"inputs": {
			"clip_name": "qwen_3_8b_fp8mixed.safetensors",
			"type": "flux2",
			"device": "default"
		}
	},
	"75:72": {
		"class_type": "VAELoader",
		"inputs": {
			"vae_name": "flux2-vae.safetensors"
		}
	},
	"75:66": {
		"class_type": "EmptyFlux2LatentImage",
		"inputs": {
			"width": ["75:81", 0],
			"height": ["75:81", 1],
			"batch_size": 1
		}
	},
	"75:80": {
		"class_type": "ImageScaleToTotalPixels",
		"inputs": {
			"upscale_method": "lanczos",
			"megapixels": 1,
			"resolution_steps": 1,
			"image": ["76", 0]
		}
	},
	"75:63": {
		"class_type": "CFGGuider",
		"inputs": {
			"cfg": 7.0,
			"model": ["75:70", 0],
			"positive": ["75:79:77", 0],
			"negative": ["75:79:76", 0]
		}
	},
	"75:62": {
		"class_type": "Flux2Scheduler",
		"inputs": {
			"steps": 25,
			"width": ["75:81", 0],
			"height": ["75:81", 1]
		}
	},
	"75:74": {
		"class_type": "CLIPTextEncode",
		"inputs": {
			"text": "",
			"clip": ["75:71", 0]
		}
	},
	"75:81": {
		"class_type": "GetImageSize",
		"inputs": {
			"image": ["75:80", 0]
		}
	},
	"75:79:76": {
		"class_type": "ReferenceLatent",
		"inputs": {
			"conditioning": ["75:82", 0],
			"latent": ["75:79:78", 0]
		}
	},
	"75:79:78": {
		"class_type": "VAEEncode",
		"inputs": {
			"pixels": ["75:80", 0],
			"vae": ["75:72", 0]
		}
	},
	"75:79:77": {
		"class_type": "ReferenceLatent",
		"inputs": {
			"conditioning": ["75:74", 0],
			"latent": ["75:79:78", 0]
		}
	},
	"75:82": {
		"class_type": "ConditioningZeroOut",
		"inputs": {
			"conditioning": ["75:74", 0]
		}
	}
}

# Workflow LivePortrait : morphing d'expression sans diffusion (pas de VAE/UNet).
# Utilise ExpressionEditor (PHM) du pack ComfyUI-AdvancedLivePortrait.
# sample_ratio=0 : l'expression vient uniquement des sliders, pas d'un sample.
const LIVE_PORTRAIT_WORKFLOW_TEMPLATE: Dictionary = {
	"1": {
		"class_type": "LoadImage",
		"inputs": {
			"image": ""
		}
	},
	"10": {
		"class_type": "ExpressionEditor",
		"inputs": {
			"src_image": ["1", 0],
			"sample_ratio": 0.0,
			"sample_parts": "All",
			"rotate_pitch": 0.0,
			"rotate_yaw": 0.0,
			"rotate_roll": 0.0,
			"blink": 0.0,
			"eyebrow": 0.0,
			"wink": 0.0,
			"pupil_x": 0.0,
			"pupil_y": 0.0,
			"aaa": 0.0,
			"eee": 0.0,
			"woo": 0.0,
			"smile": 0.0,
			"src_ratio": 1.0,
			"sample_flag": "crop",
			"crop_factor": 1.7,
			"onnx_device": "CUDA"
		}
	},
	"20": {
		"class_type": "BiRefNetRMBG",
		"inputs": {
			"image": ["10", 0],
			"model": "BiRefNet-general",
			"refine_foreground": true,
			"background": "Alpha",
			"background_color": "#222222",
			"invert_output": false,
			"mask_blur": 0,
			"mask_offset": 0
		}
	},
	"9": {
		"class_type": "SaveImage",
		"inputs": {
			"filename_prefix": "LivePortrait",
			"images": ["20", 0]
		}
	}
}

# Mapping expression → sliders ExpressionEditor (PHM).
# Plages réelles des sliders ExpressionEditor (PHM) :
# smile: -0.3 → 1.3 | aaa: -30 → 120 | eee: -20 → 15 | woo: -20 → 15
# blink: -20 → 5 | eyebrow: -10 → 15 | wink: 0 → 25
# pupil_x/y: -15 → 15 | rotate_pitch/yaw/roll: -20 → 20
const LIVE_PORTRAIT_EXPRESSIONS: Dictionary = {
	# --- Elementary ---
	"smile": {"smile": 0.5, "aaa": 8, "eee": 2, "woo": 0, "blink": 0, "eyebrow": 3, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 0, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"sad": {"smile": -0.2, "aaa": 0, "eee": 0, "woo": 0, "blink": 2, "eyebrow": -5, "wink": 0, "pupil_x": 0, "pupil_y": 3, "rotate_pitch": 3, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"shy": {"smile": 0.15, "aaa": 0, "eee": 0, "woo": 0, "blink": 2.5, "eyebrow": -2, "wink": 0, "pupil_x": 5, "pupil_y": 3, "rotate_pitch": 3, "rotate_yaw": 4, "rotate_roll": 1, "sample_parts": "All"},
	"grumpy": {"smile": -0.25, "aaa": 0, "eee": 3, "woo": 0, "blink": 1, "eyebrow": -6, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 3, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"laughing out loud": {"smile": 1.0, "aaa": 40, "eee": 5, "woo": 0, "blink": 3, "eyebrow": 5, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": -3, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"angry": {"smile": -0.2, "aaa": 5, "eee": 4, "woo": 0, "blink": 0, "eyebrow": -7, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 3, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"surprised": {"smile": 0.0, "aaa": 25, "eee": 0, "woo": 8, "blink": -3, "eyebrow": 8, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": -3, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"scared": {"smile": -0.1, "aaa": 20, "eee": 0, "woo": 6, "blink": -3, "eyebrow": 7, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": -2, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"bored": {"smile": -0.05, "aaa": 0, "eee": 0, "woo": 0, "blink": 3, "eyebrow": -3, "wink": 0, "pupil_x": 5, "pupil_y": 3, "rotate_pitch": 3, "rotate_yaw": 3, "rotate_roll": 0, "sample_parts": "All"},
	"speaking": {"smile": 0.05, "aaa": 15, "eee": 3, "woo": 0, "blink": 0, "eyebrow": 2, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 0, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "OnlyMouth"},
	"happy": {"smile": 0.7, "aaa": 15, "eee": 3, "woo": 0, "blink": 1.5, "eyebrow": 4, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 0, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"calm": {"smile": 0.1, "aaa": 0, "eee": 0, "woo": 0, "blink": 1.5, "eyebrow": 0, "wink": 0, "pupil_x": 0, "pupil_y": 2, "rotate_pitch": 1, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"crying": {"smile": -0.3, "aaa": 10, "eee": 0, "woo": 0, "blink": 3.5, "eyebrow": -7, "wink": 0, "pupil_x": 0, "pupil_y": 4, "rotate_pitch": 3, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"determined": {"smile": -0.05, "aaa": 0, "eee": 3, "woo": 0, "blink": 0, "eyebrow": -4, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": -2, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"exhausted": {"smile": -0.1, "aaa": 3, "eee": 0, "woo": 0, "blink": 4, "eyebrow": -4, "wink": 0, "pupil_x": 0, "pupil_y": 4, "rotate_pitch": 4, "rotate_yaw": 0, "rotate_roll": 1, "sample_parts": "All"},
	"annoyed": {"smile": -0.15, "aaa": 0, "eee": 3, "woo": 0, "blink": 0.5, "eyebrow": -6, "wink": 0, "pupil_x": 4, "pupil_y": 0, "rotate_pitch": 0, "rotate_yaw": 3, "rotate_roll": 0, "sample_parts": "All"},
	# --- Advanced ---
	"neutral": {"smile": 0.0, "aaa": 0, "eee": 0, "woo": 0, "blink": 0, "eyebrow": 0, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 0, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"worried": {"smile": -0.1, "aaa": 0, "eee": 0, "woo": 0, "blink": 0.5, "eyebrow": 5, "wink": 0, "pupil_x": 3, "pupil_y": 2, "rotate_pitch": 2, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"disgusted": {"smile": -0.2, "aaa": 0, "eee": 5, "woo": 0, "blink": 1.5, "eyebrow": -5, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 3, "rotate_yaw": 3, "rotate_roll": 0, "sample_parts": "All"},
	"confused": {"smile": -0.05, "aaa": 0, "eee": 0, "woo": 3, "blink": 0, "eyebrow": 5, "wink": 0, "pupil_x": 4, "pupil_y": 0, "rotate_pitch": 0, "rotate_yaw": 3, "rotate_roll": 2, "sample_parts": "All"},
	"proud": {"smile": 0.25, "aaa": 0, "eee": 0, "woo": 0, "blink": 0.5, "eyebrow": 3, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": -4, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"embarrassed": {"smile": 0.15, "aaa": 0, "eee": 0, "woo": 0, "blink": 2.5, "eyebrow": 2, "wink": 0, "pupil_x": 5, "pupil_y": 4, "rotate_pitch": 3, "rotate_yaw": 4, "rotate_roll": 0, "sample_parts": "All"},
	"idle": {"smile": 0.0, "aaa": 0, "eee": 0, "woo": 0, "blink": 0.5, "eyebrow": 0, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 0, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"thinking": {"smile": 0.0, "aaa": 0, "eee": 0, "woo": 0, "blink": 0.5, "eyebrow": 4, "wink": 0, "pupil_x": 5, "pupil_y": -3, "rotate_pitch": -2, "rotate_yaw": 3, "rotate_roll": 0, "sample_parts": "OnlyEyes"},
	"listening": {"smile": 0.05, "aaa": 0, "eee": 0, "woo": 0, "blink": 0, "eyebrow": 2, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 2, "rotate_yaw": 0, "rotate_roll": 1, "sample_parts": "All"},
	"cheerful": {"smile": 0.6, "aaa": 12, "eee": 3, "woo": 0, "blink": 0.5, "eyebrow": 4, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": -2, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"confident": {"smile": 0.25, "aaa": 0, "eee": 0, "woo": 0, "blink": 0.5, "eyebrow": 2, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": -3, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"playful": {"smile": 0.45, "aaa": 8, "eee": 0, "woo": 0, "blink": 0, "eyebrow": 4, "wink": 10, "pupil_x": 3, "pupil_y": 0, "rotate_pitch": -2, "rotate_yaw": 3, "rotate_roll": 2, "sample_parts": "All"},
	"curious": {"smile": 0.05, "aaa": 0, "eee": 0, "woo": 3, "blink": 0, "eyebrow": 5, "wink": 0, "pupil_x": 4, "pupil_y": -2, "rotate_pitch": -2, "rotate_yaw": 3, "rotate_roll": 1, "sample_parts": "All"},
	"warm": {"smile": 0.3, "aaa": 0, "eee": 0, "woo": 0, "blink": 1.5, "eyebrow": 1, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 2, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"friendly": {"smile": 0.4, "aaa": 5, "eee": 0, "woo": 0, "blink": 0, "eyebrow": 3, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 0, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"joyful": {"smile": 0.8, "aaa": 20, "eee": 3, "woo": 0, "blink": 2, "eyebrow": 5, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": -2, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"serene": {"smile": 0.15, "aaa": 0, "eee": 0, "woo": 0, "blink": 2, "eyebrow": 0, "wink": 0, "pupil_x": 0, "pupil_y": 2, "rotate_pitch": 2, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"enthusiastic": {"smile": 0.6, "aaa": 18, "eee": 3, "woo": 3, "blink": 0, "eyebrow": 6, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": -3, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"excited": {"smile": 0.7, "aaa": 20, "eee": 3, "woo": 4, "blink": 0, "eyebrow": 6, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": -3, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"hopeful": {"smile": 0.2, "aaa": 0, "eee": 0, "woo": 0, "blink": 0, "eyebrow": 4, "wink": 0, "pupil_x": 0, "pupil_y": -3, "rotate_pitch": -3, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"jealous": {"smile": -0.1, "aaa": 0, "eee": 3, "woo": 0, "blink": 1.5, "eyebrow": -4, "wink": 0, "pupil_x": 5, "pupil_y": 0, "rotate_pitch": 0, "rotate_yaw": 3, "rotate_roll": 0, "sample_parts": "All"},
	"dreamy": {"smile": 0.15, "aaa": 0, "eee": 0, "woo": 0, "blink": 2.5, "eyebrow": 1, "wink": 0, "pupil_x": 4, "pupil_y": -3, "rotate_pitch": -3, "rotate_yaw": 3, "rotate_roll": 1, "sample_parts": "All"},
	"mischievous": {"smile": 0.4, "aaa": 0, "eee": 3, "woo": 0, "blink": 0, "eyebrow": 3, "wink": 12, "pupil_x": 3, "pupil_y": 0, "rotate_pitch": -2, "rotate_yaw": 3, "rotate_roll": 1, "sample_parts": "All"},
	"relieved": {"smile": 0.25, "aaa": 8, "eee": 0, "woo": 0, "blink": 2, "eyebrow": 2, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 2, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"suspicious": {"smile": -0.1, "aaa": 0, "eee": 2, "woo": 0, "blink": 2, "eyebrow": -3, "wink": 0, "pupil_x": 5, "pupil_y": 0, "rotate_pitch": 0, "rotate_yaw": 3, "rotate_roll": 0, "sample_parts": "OnlyEyes"},
	"tender": {"smile": 0.2, "aaa": 0, "eee": 0, "woo": 0, "blink": 1.5, "eyebrow": 1, "wink": 0, "pupil_x": 0, "pupil_y": 2, "rotate_pitch": 2, "rotate_yaw": 0, "rotate_roll": 1, "sample_parts": "All"},
	"desperate": {"smile": -0.25, "aaa": 18, "eee": 0, "woo": 3, "blink": 3, "eyebrow": 7, "wink": 0, "pupil_x": 0, "pupil_y": 3, "rotate_pitch": 3, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
	"nostalgic": {"smile": 0.1, "aaa": 0, "eee": 0, "woo": 0, "blink": 2, "eyebrow": -1, "wink": 0, "pupil_x": 4, "pupil_y": -2, "rotate_pitch": 2, "rotate_yaw": 3, "rotate_roll": 0, "sample_parts": "All"},
	"seductive": {"smile": 0.25, "aaa": 0, "eee": 2, "woo": 0, "blink": 2, "eyebrow": 2, "wink": 0, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 3, "rotate_yaw": 3, "rotate_roll": 1, "sample_parts": "All"},
	# --- Extras ---
	"wink": {"smile": 0.3, "aaa": 0, "eee": 0, "woo": 0, "blink": 0, "eyebrow": 2, "wink": 15, "pupil_x": 0, "pupil_y": 0, "rotate_pitch": 0, "rotate_yaw": 0, "rotate_roll": 0, "sample_parts": "All"},
}

func is_generating() -> bool:
	return _generating

# --- Build workflow with dynamic parameters ---

func _build_upscale_workflow(filename: String, prompt_text: String, seed: int, denoise: float, model_name: String, tile_size: int, target_w: int, target_h: int, negative_prompt: String) -> Dictionary:
	var wf = UPSCALE_WORKFLOW_TEMPLATE.duplicate(true)
	wf["1"]["inputs"]["image"] = filename
	wf["2"]["inputs"]["model_name"] = model_name
	wf["4"]["inputs"]["width"] = target_w
	wf["4"]["inputs"]["height"] = target_h
	wf["13"]["inputs"]["text"] = prompt_text
	wf["20"]["inputs"]["denoise"] = denoise
	wf["20"]["inputs"]["seed"] = seed
	wf["20"]["inputs"]["tile_width"] = tile_size
	wf["20"]["inputs"]["tile_height"] = tile_size
	if negative_prompt.strip_edges() != "":
		wf["75:83"] = {
			"class_type": "CLIPTextEncode",
			"inputs": {
				"text": negative_prompt,
				"clip": ["75:71", 0]
			}
		}
		wf["20"]["inputs"]["negative"] = ["75:83", 0]
		wf.erase("14")
	return wf


func _build_hires_workflow(filename: String, prompt_text: String, seed: int, cfg: float, steps: int, denoise: float, negative_prompt: String, megapixels: float = 1.0) -> Dictionary:
	var wf = HIRES_WORKFLOW_TEMPLATE.duplicate(true)
	wf["76"]["inputs"]["image"] = filename
	wf["75:74"]["inputs"]["text"] = prompt_text
	wf["75:73"]["inputs"]["noise_seed"] = seed
	wf["75:63"]["inputs"]["cfg"] = cfg
	wf["75:62"]["inputs"]["steps"] = steps
	wf["75:80"]["inputs"]["megapixels"] = megapixels
	_apply_negative_prompt(wf, negative_prompt)
	# img2img : partir du latent encodé de l'image source (pas d'un canvas vierge)
	wf["75:64"]["inputs"]["latent_image"] = ["75:79:78", 0]
	# SplitSigmas : contrôle du denoise (même logique que le workflow Expression)
	var split_step = max(1, roundi(steps * (1.0 - denoise)))
	wf["split_sigmas"] = {
		"class_type": "SplitSigmas",
		"inputs": {
			"sigmas": ["75:62", 0],
			"step": split_step
		}
	}
	wf["75:64"]["inputs"]["sigmas"] = ["split_sigmas", 1]
	# EmptyFlux2LatentImage n'est pas utilisé (on encode la source)
	wf.erase("75:66")
	return wf


func _build_live_portrait_workflow(filename: String, expression: String, remove_background: bool) -> Dictionary:
	var wf = LIVE_PORTRAIT_WORKFLOW_TEMPLATE.duplicate(true)
	wf["1"]["inputs"]["image"] = filename
	# Appliquer les sliders de l'expression
	var expr_key = expression.to_lower().strip_edges()
	var sliders: Dictionary = LIVE_PORTRAIT_EXPRESSIONS.get(expr_key, LIVE_PORTRAIT_EXPRESSIONS["neutral"])
	for key in sliders:
		if wf["10"]["inputs"].has(key):
			wf["10"]["inputs"][key] = sliders[key]
	if not remove_background:
		wf["9"]["inputs"]["images"] = ["10", 0]
		wf.erase("20")
	return wf


func _inject_loras(wf: Dictionary, loras: Array) -> void:
	if loras.is_empty():
		return
	var last_node_id = ""
	for i in range(loras.size()):
		var lora = loras[i]
		var node_id = "lora_%d" % i
		var model_in = ["75:70", 0] if i == 0 else [last_node_id, 0]
		var clip_in = ["75:71", 0] if i == 0 else [last_node_id, 1]
		wf[node_id] = {
			"class_type": "LoraLoader",
			"inputs": {
				"model": model_in,
				"clip": clip_in,
				"lora_name": lora["name"],
				"strength_model": lora["strength"],
				"strength_clip": lora["strength"]
			}
		}
		last_node_id = node_id
	wf["75:63"]["inputs"]["model"] = [last_node_id, 0]
	wf["75:74"]["inputs"]["clip"] = [last_node_id, 1]


func build_workflow(filename: String, prompt_text: String, seed: int, remove_background: bool = true, cfg: float = 1.0, steps: int = 4, workflow_type: int = WorkflowType.CREATION, denoise: float = 0.5, negative_prompt: String = "", face_box_size: int = 80, megapixels: float = 1.0, loras: Array = []) -> Dictionary:
	if workflow_type == WorkflowType.UPSCALE:
		return _build_upscale_workflow(filename, prompt_text, seed, denoise, _upscale_model_name, _upscale_tile_size, _upscale_target_w, _upscale_target_h, negative_prompt)
	if workflow_type == WorkflowType.HIRES:
		return _build_hires_workflow(filename, prompt_text, seed, cfg, steps, denoise, negative_prompt, megapixels)
	if workflow_type == WorkflowType.EXPRESSION:
		return _build_expression_workflow(filename, prompt_text, seed, remove_background, cfg, steps, denoise, negative_prompt, face_box_size, megapixels)
	if workflow_type == WorkflowType.EXPRESSION_FACE_DETAILER:
		return _build_face_detailer_workflow(filename, prompt_text, seed, cfg, steps, denoise, negative_prompt, face_box_size)
	if workflow_type == WorkflowType.EXPRESSION_LIVE_PORTRAIT:
		return _build_live_portrait_workflow(filename, prompt_text, remove_background)
	var wf = WORKFLOW_TEMPLATE.duplicate(true)
	wf["76"]["inputs"]["image"] = filename
	wf["75:74"]["inputs"]["text"] = prompt_text
	wf["75:73"]["inputs"]["noise_seed"] = seed
	wf["75:63"]["inputs"]["cfg"] = cfg
	wf["75:62"]["inputs"]["steps"] = steps
	wf["75:80"]["inputs"]["megapixels"] = megapixels
	_apply_negative_prompt(wf, negative_prompt)
	_inject_loras(wf, loras)
	if not remove_background:
		# Pour les backgrounds : sauvegarder directement la sortie du VAEDecode
		# sans passer par BiRefNetRMBG (pas de suppression de fond)
		wf["9"]["inputs"]["images"] = ["75:65", 0]
		wf.erase("100")
	return wf

func _build_expression_workflow(filename: String, prompt_text: String, seed: int, remove_background: bool, cfg: float, steps: int, denoise: float = 0.5, negative_prompt: String = "", face_box_size: int = 80, megapixels: float = 1.0) -> Dictionary:
	var wf = EXPRESSION_WORKFLOW_TEMPLATE.duplicate(true)
	# Appliquer la taille de la zone visage (dilation + expand)
	wf["100"]["inputs"]["dilation"] = face_box_size
	wf["101"]["inputs"]["expand"] = face_box_size
	# Blur proportionnel à face_box_size (référence : kernel=51 sigma=25 pour face_box_size=80)
	# Plancher minimum : kernel≥21 sigma≥10 pour garantir un fondu suffisant quelle que soit la valeur
	var blur_kernel: int = max(21, roundi(face_box_size * 51.0 / 80.0)) | 1  # toujours impair
	var blur_sigma: float = maxf(10.0, face_box_size * 25.0 / 80.0)
	wf["102"]["inputs"]["kernel_size"] = blur_kernel
	wf["102"]["inputs"]["sigma"] = blur_sigma
	wf["76"]["inputs"]["image"] = filename
	wf["75:74"]["inputs"]["text"] = prompt_text
	wf["75:73"]["inputs"]["noise_seed"] = seed
	wf["75:63"]["inputs"]["cfg"] = cfg
	wf["75:62"]["inputs"]["steps"] = steps
	wf["75:80"]["inputs"]["megapixels"] = megapixels
	_apply_negative_prompt(wf, negative_prompt)
	# img2img : partir de l'image source encodée (pas d'un canvas vierge)
	# pour préserver les caractéristiques visuelles (couleur des yeux, etc.)
	wf["75:64"]["inputs"]["latent_image"] = ["75:79:78", 0]
	# SplitSigmas : contrôle du denoise (0.1 = peu de changement, 1.0 = régénération totale)
	var split_step = max(1, roundi(steps * (1.0 - denoise)))
	wf["split_sigmas"] = {
		"class_type": "SplitSigmas",
		"inputs": {
			"sigmas": ["75:62", 0],
			"step": split_step
		}
	}
	wf["75:64"]["inputs"]["sigmas"] = ["split_sigmas", 1]
	# EmptyFlux2LatentImage n'est plus utilisé
	wf.erase("75:66")
	if not remove_background:
		wf["9"]["inputs"]["images"] = ["103", 0]
		wf.erase("106")
	return wf

func _build_face_detailer_workflow(filename: String, prompt_text: String, seed: int, cfg: float, steps: int, denoise: float, negative_prompt: String, face_box_size: int = 80) -> Dictionary:
	var wf = FACE_DETAILER_WORKFLOW_TEMPLATE.duplicate(true)
	wf["76"]["inputs"]["image"] = filename
	wf["75:74"]["inputs"]["text"] = prompt_text
	wf["200"]["inputs"]["seed"] = seed
	wf["200"]["inputs"]["cfg"] = cfg
	wf["200"]["inputs"]["steps"] = steps
	wf["200"]["inputs"]["denoise"] = denoise
	wf["200"]["inputs"]["bbox_dilation"] = face_box_size
	if negative_prompt.strip_edges() != "":
		wf["75:83"] = {
			"class_type": "CLIPTextEncode",
			"inputs": {
				"text": negative_prompt,
				"clip": ["75:71", 0]
			}
		}
		wf["200"]["inputs"]["negative"] = ["75:83", 0]
		wf.erase("75:82")
	return wf


func _apply_negative_prompt(wf: Dictionary, negative_prompt: String) -> void:
	if negative_prompt.strip_edges() == "":
		return
	# Remplacer ConditioningZeroOut par un vrai CLIPTextEncode pour le negative prompt
	wf["75:83"] = {
		"class_type": "CLIPTextEncode",
		"inputs": {
			"text": negative_prompt,
			"clip": ["75:71", 0]
		}
	}
	wf["75:79:76"]["inputs"]["conditioning"] = ["75:83", 0]
	wf.erase("75:82")

# --- Multipart body builder ---

func build_multipart_body(filename: String, file_bytes: PackedByteArray) -> Array:
	var boundary = "----GodotBoundary" + str(randi())

	var body = PackedByteArray()

	# File part
	var file_header = "--%s\r\nContent-Disposition: form-data; name=\"image\"; filename=\"%s\"\r\nContent-Type: image/png\r\n\r\n" % [boundary, filename]
	body.append_array(file_header.to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array("\r\n".to_utf8_buffer())

	# Overwrite: force ComfyUI to replace existing image with same name
	var overwrite_part = "--%s\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n" % boundary
	body.append_array(overwrite_part.to_utf8_buffer())

	# Closing boundary
	var closing = "--%s--\r\n" % boundary
	body.append_array(closing.to_utf8_buffer())

	return [body, boundary]

# --- Parse responses ---

func parse_prompt_response(json_str: String) -> String:
	if json_str.is_empty():
		return ""
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		return ""
	var data = json.data
	if data is Dictionary and data.has("prompt_id"):
		return data["prompt_id"]
	return ""

func parse_history_response(json_str: String, prompt_id: String) -> Dictionary:
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		return {"status": "error", "error": "Réponse JSON invalide"}
	var data = json.data
	if not data is Dictionary or not data.has(prompt_id):
		return {"status": "pending"}
	var entry = data[prompt_id]
	if not entry is Dictionary:
		return {"status": "error", "error": "Entrée invalide dans l'historique"}
	# Check if still running via status field (when present)
	if entry.has("status"):
		var status_info = entry["status"]
		if status_info is Dictionary:
			if not status_info.get("completed", false):
				# Check for node errors in status_messages
				if status_info.has("messages"):
					for msg in status_info["messages"]:
						if msg is Array and msg.size() >= 2 and msg[0] == "execution_error":
							var error_detail = msg[1]
							if error_detail is Dictionary:
								var node_type = error_detail.get("node_type", "unknown")
								var exception_message = error_detail.get("exception_message", "")
								return {"status": "error", "error": "%s: %s" % [node_type, exception_message]}
				return {"status": "pending"}
	if not entry.has("outputs"):
		return {"status": "error", "error": "Pas de sorties dans l'historique"}
	# Find the output node with images — prefer type "output" over "temp"
	var outputs = entry["outputs"]
	var fallback_filename := ""
	for node_id in outputs:
		var node_output = outputs[node_id]
		if node_output is Dictionary and node_output.has("images"):
			var images = node_output["images"]
			if images is Array and images.size() > 0:
				var img = images[0]
				var img_type = img.get("type", "output")
				print("[ComfyUI] history node=%s filename=%s type=%s" % [node_id, img["filename"], img_type])
				if img_type == "output":
					return {"status": "completed", "filename": img["filename"]}
				elif fallback_filename == "":
					fallback_filename = img["filename"]
	if fallback_filename != "":
		return {"status": "completed", "filename": fallback_filename}
	return {"status": "error", "error": "Aucune image dans les sorties"}

# --- Full generation flow ---

func generate(config: RefCounted, source_image_path: String, prompt_text: String, remove_background: bool = true, cfg: float = 1.0, steps: int = 4, workflow_type: int = WorkflowType.CREATION, denoise: float = 0.5, negative_prompt: String = "", face_box_size: int = 80, upscale_model_name: String = "4x-UltraSharp.pth", tile_size: int = 512, target_w: int = 0, target_h: int = 0, megapixels: float = 1.0, loras: Array = []) -> void:
	if _generating:
		generation_failed.emit("Une génération est déjà en cours")
		return

	_generating = true
	_cancelled = false
	_config = config
	_remove_background = remove_background
	_cfg = cfg
	_steps = steps
	_denoise = denoise
	_workflow_type = workflow_type
	_negative_prompt = negative_prompt
	_face_box_size = face_box_size
	_upscale_model_name = upscale_model_name
	_upscale_tile_size = tile_size
	_upscale_target_w = target_w
	_upscale_target_h = target_h
	_megapixels = megapixels
	_loras = loras

	generation_progress.emit("Chargement de l'image source...")

	# Load source image file bytes
	var file = FileAccess.open(source_image_path, FileAccess.READ)
	if file == null:
		_generating = false
		generation_failed.emit("Impossible d'ouvrir l'image : " + source_image_path)
		return

	var file_bytes = file.get_buffer(file.get_length())
	file.close()

	var filename = source_image_path.get_file()

	# Step 1: Upload
	generation_progress.emit("Upload de l'image vers ComfyUI...")
	_do_upload(filename, file_bytes, prompt_text)

func _do_upload(filename: String, file_bytes: PackedByteArray, prompt_text: String) -> void:
	var multipart = build_multipart_body(filename, file_bytes)
	var body_bytes: PackedByteArray = multipart[0]
	var boundary: String = multipart[1]

	var http = HTTPRequest.new()
	add_child(http)

	var url = _config.get_full_url("/upload/image")
	var headers: Array = ["Content-Type: multipart/form-data; boundary=" + boundary]
	for h in _config.get_auth_headers():
		headers.append(h)

	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if _cancelled:
			_generating = false
			return
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_generating = false
			generation_failed.emit("Erreur upload (code %d, result %d)" % [code, result])
			return
		generation_progress.emit("Image uploadée. Lancement du workflow...")
		_do_prompt(filename, prompt_text)
	)

	http.request_raw(url, PackedStringArray(headers), HTTPClient.METHOD_POST, body_bytes)

func _do_prompt(filename: String, prompt_text: String) -> void:
	var seed = randi()
	var workflow = build_workflow(filename, prompt_text, seed, _remove_background, _cfg, _steps, _workflow_type, _denoise, _negative_prompt, _face_box_size, _megapixels, _loras)

	# --- DEBUG LOGS ---
	var wt_name = WorkflowType.keys()[_workflow_type] if _workflow_type < WorkflowType.size() else str(_workflow_type)
	print("[ComfyUI] === PROMPT DEBUG ===")
	print("[ComfyUI] workflow_type : ", wt_name)
	print("[ComfyUI] image         : ", filename)
	print("[ComfyUI] prompt        : ", prompt_text)
	print("[ComfyUI] seed          : ", seed)
	print("[ComfyUI] cfg           : ", _cfg)
	print("[ComfyUI] steps         : ", _steps)
	print("[ComfyUI] denoise       : ", _denoise)
	print("[ComfyUI] megapixels    : ", _megapixels, " (ignoré pour FaceDetailer)")
	print("[ComfyUI] face_box_size : ", _face_box_size)
	print("[ComfyUI] neg_prompt    : '", _negative_prompt, "'")
	if _workflow_type == WorkflowType.EXPRESSION_FACE_DETAILER and workflow.has("200"):
		var fd = workflow["200"]["inputs"]
		print("[ComfyUI] --- FaceDetailer node ---")
		print("[ComfyUI]   guide_size      : ", fd.get("guide_size"))
		print("[ComfyUI]   sampler_name    : ", fd.get("sampler_name"))
		print("[ComfyUI]   scheduler       : ", fd.get("scheduler"))
		print("[ComfyUI]   bbox_dilation   : ", fd.get("bbox_dilation"))
		print("[ComfyUI]   bbox_crop_factor: ", fd.get("bbox_crop_factor"))
		print("[ComfyUI]   noise_mask      : ", fd.get("noise_mask"))
		print("[ComfyUI]   force_inpaint   : ", fd.get("force_inpaint"))
		print("[ComfyUI]   negative node   : ", workflow["200"]["inputs"].get("negative"))
	if _workflow_type == WorkflowType.EXPRESSION_LIVE_PORTRAIT and workflow.has("10"):
		var ee = workflow["10"]["inputs"]
		print("[ComfyUI] --- LivePortrait workflow (pas de diffusion) ---")
		print("[ComfyUI]   expression      : ", prompt_text)
		print("[ComfyUI]   smile=%.2f aaa=%.2f eee=%.2f woo=%.2f" % [ee.get("smile", 0), ee.get("aaa", 0), ee.get("eee", 0), ee.get("woo", 0)])
		print("[ComfyUI]   blink=%.2f eyebrow=%.2f wink=%.2f" % [ee.get("blink", 0), ee.get("eyebrow", 0), ee.get("wink", 0)])
		print("[ComfyUI]   pupil_x=%.2f pupil_y=%.2f" % [ee.get("pupil_x", 0), ee.get("pupil_y", 0)])
		print("[ComfyUI]   rotate pitch=%.2f yaw=%.2f roll=%.2f" % [ee.get("rotate_pitch", 0), ee.get("rotate_yaw", 0), ee.get("rotate_roll", 0)])
		print("[ComfyUI]   sample_ratio=%.1f sample_parts=%s" % [ee.get("sample_ratio", 0), ee.get("sample_parts", "")])
		print("[ComfyUI]   BiRefNet : ", "oui" if workflow.has("20") else "non (fond conservé)")
	if _workflow_type == WorkflowType.EXPRESSION:
		var split_step = max(1, roundi(_steps * (1.0 - _denoise)))
		var effective_steps = _steps - split_step
		print("[ComfyUI] --- Expression workflow ---")
		print("[ComfyUI]   megapixels      : ", workflow["75:80"]["inputs"].get("megapixels"))
		print("[ComfyUI]   face dilation   : ", workflow["100"]["inputs"].get("dilation"), "  (nœud BboxDetectorCombined_v2)")
		print("[ComfyUI]   face expand     : ", workflow["101"]["inputs"].get("expand"),    "  (nœud GrowMask)")
		var log_kernel = max(21, roundi(_face_box_size * 51.0 / 80.0)) | 1
		var log_sigma  = maxf(10.0, _face_box_size * 25.0 / 80.0)
		print("[ComfyUI]   mask blur       : kernel=%d sigma=%.1f  (proportionnel à face_box_size=%d)" % [log_kernel, log_sigma, _face_box_size])
		print("[ComfyUI]   SplitSigmas step: ", split_step, " sur ", _steps, " → ", effective_steps, " step(s) effectif(s) de débruitage")
		print("[ComfyUI]   (denoise=1.0 → split_step=1 → ", _steps - 1, " steps actifs | denoise=0.5 → ", _steps / 2, " steps actifs)")
		print("[ComfyUI]   latent_image    : source encodée (VAEEncode 75:79:78) → img2img")
		print("[ComfyUI]   sigmas utilisés : split_sigmas[1] = sigmas[", split_step, ":] (faible bruit seulement)")
		var neg_node = workflow.get("75:83")
		if neg_node:
			print("[ComfyUI]   negative prompt : '", neg_node["inputs"].get("text"), "' via CLIPTextEncode 75:83")
		else:
			print("[ComfyUI]   negative prompt : ConditioningZeroOut (pas de négatif actif)")
	print("[ComfyUI] full workflow JSON : ", JSON.stringify(workflow))
	print("[ComfyUI] ====================")
	# --- FIN DEBUG ---

	var payload = JSON.stringify({"prompt": workflow})

	var http = HTTPRequest.new()
	add_child(http)

	var url = _config.get_full_url("/prompt")
	var headers: Array = ["Content-Type: application/json"]
	for h in _config.get_auth_headers():
		headers.append(h)

	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if _cancelled:
			_generating = false
			return
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_generating = false
			var response_str = body.get_string_from_utf8()
			print("[ComfyUI] ERREUR prompt (code %d) : %s" % [code, response_str])
			generation_failed.emit("Erreur prompt (code %d) : %s" % [code, response_str.left(500)])
			return
		var response_str = body.get_string_from_utf8()
		_prompt_id = parse_prompt_response(response_str)
		if _prompt_id.is_empty():
			_generating = false
			generation_failed.emit("Réponse invalide du serveur (pas de prompt_id)")
			return
		generation_progress.emit("Génération en cours...")
		_start_polling()
	)

	http.request(url, PackedStringArray(headers), HTTPClient.METHOD_POST, payload)

func _start_polling() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 1.5
	_poll_timer.timeout.connect(_poll_history)
	add_child(_poll_timer)
	_poll_timer.start()

func _poll_history() -> void:
	if _cancelled:
		_stop_polling()
		_generating = false
		return

	var http = HTTPRequest.new()
	add_child(http)

	var url = _config.get_full_url("/history/" + _prompt_id)
	var headers: Array = []
	for h in _config.get_auth_headers():
		headers.append(h)

	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if _cancelled:
			_stop_polling()
			_generating = false
			return
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return  # Retry on next poll
		var response_str = body.get_string_from_utf8()
		var parsed = parse_history_response(response_str, _prompt_id)
		if parsed["status"] == "completed":
			_stop_polling()
			generation_progress.emit("Téléchargement du résultat...")
			_do_download(parsed["filename"])
		elif parsed["status"] == "error":
			_stop_polling()
			_generating = false
			var error_msg = parsed.get("error", "Erreur inconnue")
			generation_failed.emit("Erreur workflow : %s" % error_msg)
	)

	http.request(url, PackedStringArray(headers))

func _stop_polling() -> void:
	if _poll_timer != null:
		_poll_timer.stop()
		_poll_timer.queue_free()
		_poll_timer = null

func _do_download(filename: String) -> void:
	print("[ComfyUI] downloading: %s" % filename)
	var http = HTTPRequest.new()
	add_child(http)

	var url = _config.get_full_url("/view?filename=" + filename.uri_encode() + "&type=output")
	var headers: Array = []
	for h in _config.get_auth_headers():
		headers.append(h)

	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		_generating = false
		if _cancelled:
			return
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			generation_failed.emit("Erreur téléchargement (code %d)" % code)
			return
		print("[ComfyUI] received %d bytes" % body.size())
		var image = Image.new()
		var err = image.load_png_from_buffer(body)
		if err != OK:
			err = image.load_jpg_from_buffer(body)
		if err != OK:
			err = image.load_webp_from_buffer(body)
		if err != OK:
			generation_failed.emit("Impossible de décoder l'image reçue")
			return
		generation_completed.emit(image)
	)

	http.request(url, PackedStringArray(headers))

func cancel() -> void:
	_cancelled = true
	if _generating:
		_stop_polling()
		_generating = false
		generation_progress.emit("Génération annulée")
