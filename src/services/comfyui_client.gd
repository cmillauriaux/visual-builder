# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Node

## Client HTTP pour ComfyUI. Gère upload, prompt, polling et download.

const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")

signal generation_completed(image: Image)
signal generation_failed(error: String)
signal generation_progress(status: String)


func _fail(error: String) -> void:
	print("[ComfyUI] FAILED: ", error)
	generation_failed.emit(error)

enum WorkflowType { CREATION = 0, EXPRESSION = 1, OUTPAINT = 2, UPSCALE = 3, ENHANCE = 4, UPSCALE_ENHANCE = 5, BLINK = 6, INPAINT = 7 }

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
var _megapixels: float = 1.0
var _loras: Array = []
var _source_filename: String = ""
var _second_image_filename: String = ""
var _second_image_bytes: PackedByteArray = PackedByteArray()
var _outpaint_left: int = 0
var _outpaint_top: int = 0
var _outpaint_right: int = 0
var _outpaint_bottom: int = 0
var _outpaint_feathering: int = 24
var _outpaint_guidance: float = 40.0
var _upscale_factor: float = 2.0
var _enhance_shift: float = 3.0
var _eye_zone_mode: String = "eyes_only"  # "eyes_only" ou "eyes_and_brows"
var _debug_mask: bool = false
var _mask_feather: int = 15
var _detection_scale: float = 1.0
var _backbone: String = "resnet18"
var _detection_model: String = "bisenet"  # "bisenet" ou nom de fichier YOLO .pt
var _detection_threshold: float = 0.3
var _mask_filename: String = ""
var _mask_bytes_data: PackedByteArray = PackedByteArray()
var _inpaint_guidance: float = 30.0

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
			"unet_name": "flux-2-klein-9b-fp8.safetensors",
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
			"unet_name": "flux-2-klein-9b-fp8.safetensors",
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





# --- Outpaint workflow template (Flux Fill + ImagePadForOutpaint) ---
# Reproduit le workflow flux_fill_outpaint.
# Paramètres dynamiques : 17.inputs.image, 23.inputs.text, 3.inputs.seed,
#                         44.inputs.left/top/right/bottom/feathering,
#                         26.inputs.guidance, 3.inputs.cfg, 3.inputs.steps

const OUTPAINT_WORKFLOW_TEMPLATE: Dictionary = {
	"3": {
		"class_type": "KSampler",
		"inputs": {
			"seed": 0,
			"steps": 20,
			"cfg": 0.7,
			"sampler_name": "euler",
			"scheduler": "normal",
			"denoise": 1,
			"model": ["39", 0],
			"positive": ["38", 0],
			"negative": ["38", 1],
			"latent_image": ["38", 2]
		}
	},
	"8": {
		"class_type": "VAEDecode",
		"inputs": {
			"samples": ["3", 0],
			"vae": ["32", 0]
		}
	},
	"9": {
		"class_type": "SaveImage",
		"inputs": {
			"filename_prefix": "Outpaint",
			"images": ["8", 0]
		}
	},
	"17": {
		"class_type": "LoadImage",
		"inputs": {
			"image": ""
		}
	},
	"23": {
		"class_type": "CLIPTextEncode",
		"inputs": {
			"text": "",
			"clip": ["34", 0]
		}
	},
	"26": {
		"class_type": "FluxGuidance",
		"inputs": {
			"guidance": 40,
			"conditioning": ["23", 0]
		}
	},
	"31": {
		"class_type": "UNETLoader",
		"inputs": {
			"unet_name": "flux1-fill-dev.safetensors",
			"weight_dtype": "default"
		}
	},
	"32": {
		"class_type": "VAELoader",
		"inputs": {
			"vae_name": "ae.safetensors"
		}
	},
	"34": {
		"class_type": "DualCLIPLoader",
		"inputs": {
			"clip_name1": "clip_l.safetensors",
			"clip_name2": "t5xxl_fp16.safetensors",
			"type": "flux",
			"device": "default"
		}
	},
	"38": {
		"class_type": "InpaintModelConditioning",
		"inputs": {
			"noise_mask": false,
			"positive": ["26", 0],
			"negative": ["46", 0],
			"vae": ["32", 0],
			"pixels": ["44", 0],
			"mask": ["44", 1]
		}
	},
	"39": {
		"class_type": "DifferentialDiffusion",
		"inputs": {
			"strength": 1,
			"model": ["31", 0]
		}
	},
	"44": {
		"class_type": "ImagePadForOutpaint",
		"inputs": {
			"left": 0,
			"top": 0,
			"right": 0,
			"bottom": 0,
			"feathering": 24,
			"image": ["17", 0]
		}
	},
	"46": {
		"class_type": "ConditioningZeroOut",
		"inputs": {
			"conditioning": ["23", 0]
		}
	}
}

# --- Inpainting workflow template (Flux Fill + masque utilisateur) ---
# Basé sur OUTPAINT_WORKFLOW_TEMPLATE sans ImagePadForOutpaint (nœud 44).
# L'image source est câblée directement dans InpaintModelConditioning.pixels.
# Le masque PNG généré par l'utilisateur est injecté dynamiquement.
# Paramètres dynamiques : 17.inputs.image, 23.inputs.text, 3.inputs.seed/steps/denoise,
#                         26.inputs.guidance, 38.inputs.mask=[final_mask_node,0]

const INPAINT_FILL_WORKFLOW_TEMPLATE: Dictionary = {
	"3": {
		"class_type": "KSampler",
		"inputs": {
			"seed": 0,
			"steps": 20,
			"cfg": 0.7,
			"sampler_name": "euler",
			"scheduler": "normal",
			"denoise": 1.0,
			"model": ["39", 0],
			"positive": ["38", 0],
			"negative": ["38", 1],
			"latent_image": ["38", 2]
		}
	},
	"8": {
		"class_type": "VAEDecode",
		"inputs": {
			"samples": ["3", 0],
			"vae": ["32", 0]
		}
	},
	"9": {
		"class_type": "SaveImage",
		"inputs": {
			"filename_prefix": "Inpaint",
			"images": ["8", 0]
		}
	},
	"17": {
		"class_type": "LoadImage",
		"inputs": {
			"image": ""
		}
	},
	"23": {
		"class_type": "CLIPTextEncode",
		"inputs": {
			"text": "",
			"clip": ["34", 0]
		}
	},
	"26": {
		"class_type": "FluxGuidance",
		"inputs": {
			"guidance": 30.0,
			"conditioning": ["23", 0]
		}
	},
	"31": {
		"class_type": "UNETLoader",
		"inputs": {
			"unet_name": "flux1-fill-dev.safetensors",
			"weight_dtype": "default"
		}
	},
	"32": {
		"class_type": "VAELoader",
		"inputs": {
			"vae_name": "ae.safetensors"
		}
	},
	"34": {
		"class_type": "DualCLIPLoader",
		"inputs": {
			"clip_name1": "clip_l.safetensors",
			"clip_name2": "t5xxl_fp16.safetensors",
			"type": "flux",
			"device": "default"
		}
	},
	"38": {
		"class_type": "InpaintModelConditioning",
		"inputs": {
			"noise_mask": false,
			"positive": ["26", 0],
			"negative": ["46", 0],
			"vae": ["32", 0],
			"pixels": ["17", 0],
			"mask": []
		}
	},
	"39": {
		"class_type": "DifferentialDiffusion",
		"inputs": {
			"strength": 1,
			"model": ["31", 0]
		}
	},
	"46": {
		"class_type": "ConditioningZeroOut",
		"inputs": {
			"conditioning": ["23", 0]
		}
	}
}


# --- Upscale / Enhance workflow template (z-image-turbo + RealESRGAN) ---
# Base complète utilisée pour Upscale+Enhance. Les builders Upscale-only et
# Enhance-only suppriment les nœuds non nécessaires.
# Paramètres dynamiques : 77.inputs.image, 87:67.inputs.text, 87:69.inputs.seed/steps/cfg/denoise,
#                         87:81.inputs.scale_by, 87:70.inputs.shift, 87:78.inputs.megapixels

const UPSCALE_ENHANCE_WORKFLOW_TEMPLATE: Dictionary = {
	"9": {
		"class_type": "SaveImage",
		"inputs": {
			"filename_prefix": "z-image-upscaled",
			"images": ["87:65", 0]
		}
	},
	"77": {
		"class_type": "LoadImage",
		"inputs": {
			"image": ""
		}
	},
	"87:76": {
		"class_type": "UpscaleModelLoader",
		"inputs": {
			"model_name": "RealESRGAN_x4plus.safetensors"
		}
	},
	"87:78": {
		"class_type": "ImageScaleToTotalPixels",
		"inputs": {
			"upscale_method": "lanczos",
			"megapixels": 1,
			"resolution_steps": 1,
			"image": ["77", 0]
		}
	},
	"87:79": {
		"class_type": "ImageUpscaleWithModel",
		"inputs": {
			"upscale_model": ["87:76", 0],
			"image": ["87:78", 0]
		}
	},
	"87:81": {
		"class_type": "ImageScaleBy",
		"inputs": {
			"upscale_method": "lanczos",
			"scale_by": 0.5,
			"image": ["87:79", 0]
		}
	},
	"87:66": {
		"class_type": "UNETLoader",
		"inputs": {
			"unet_name": "z_image_turbo_bf16.safetensors",
			"weight_dtype": "default"
		}
	},
	"87:62": {
		"class_type": "CLIPLoader",
		"inputs": {
			"clip_name": "qwen_3_4b.safetensors",
			"type": "lumina2",
			"device": "default"
		}
	},
	"87:63": {
		"class_type": "VAELoader",
		"inputs": {
			"vae_name": "ae.safetensors"
		}
	},
	"87:70": {
		"class_type": "ModelSamplingAuraFlow",
		"inputs": {
			"shift": 3,
			"model": ["87:66", 0]
		}
	},
	"87:67": {
		"class_type": "CLIPTextEncode",
		"inputs": {
			"text": "",
			"clip": ["87:62", 0]
		}
	},
	"87:71": {
		"class_type": "CLIPTextEncode",
		"inputs": {
			"text": "",
			"clip": ["87:62", 0]
		}
	},
	"87:80": {
		"class_type": "VAEEncode",
		"inputs": {
			"pixels": ["87:81", 0],
			"vae": ["87:63", 0]
		}
	},
	"87:69": {
		"class_type": "KSampler",
		"inputs": {
			"seed": 0,
			"steps": 5,
			"cfg": 1,
			"sampler_name": "dpmpp_2m_sde",
			"scheduler": "beta",
			"denoise": 0.2,
			"model": ["87:70", 0],
			"positive": ["87:67", 0],
			"negative": ["87:71", 0],
			"latent_image": ["87:80", 0]
		}
	},
	"87:65": {
		"class_type": "VAEDecode",
		"inputs": {
			"samples": ["87:69", 0],
			"vae": ["87:63", 0]
		}
	}
}


func is_generating() -> bool:
	return _generating


static func build_mask_bytes(rect: Rect2i, img_width: int, img_height: int) -> PackedByteArray:
	var img = Image.create(img_width, img_height, false, Image.FORMAT_L8)
	img.fill(Color(0.0, 0.0, 0.0))
	if rect.size.x > 0 and rect.size.y > 0:
		var clamped = Rect2i(
			clampi(rect.position.x, 0, img_width - 1),
			clampi(rect.position.y, 0, img_height - 1),
			0, 0
		)
		clamped.size.x = clampi(rect.size.x, 1, img_width - clamped.position.x)
		clamped.size.y = clampi(rect.size.y, 1, img_height - clamped.position.y)
		img.fill_rect(clamped, Color(1.0, 1.0, 1.0))
	return img.save_png_to_buffer()


# --- Build workflow with dynamic parameters ---

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


func _build_outpaint_workflow(filename: String, prompt_text: String, seed: int, cfg: float, steps: int, negative_prompt: String) -> Dictionary:
	var wf = OUTPAINT_WORKFLOW_TEMPLATE.duplicate(true)
	wf["17"]["inputs"]["image"] = filename
	wf["23"]["inputs"]["text"] = prompt_text
	wf["3"]["inputs"]["seed"] = seed
	wf["3"]["inputs"]["steps"] = steps
	wf["3"]["inputs"]["cfg"] = cfg
	wf["26"]["inputs"]["guidance"] = _outpaint_guidance
	wf["44"]["inputs"]["left"] = _outpaint_left
	wf["44"]["inputs"]["top"] = _outpaint_top
	wf["44"]["inputs"]["right"] = _outpaint_right
	wf["44"]["inputs"]["bottom"] = _outpaint_bottom
	wf["44"]["inputs"]["feathering"] = _outpaint_feathering
	# Negative prompt : remplacer ConditioningZeroOut par CLIPTextEncode si fourni
	if negative_prompt.strip_edges() != "":
		wf["47"] = {
			"class_type": "CLIPTextEncode",
			"inputs": {
				"text": negative_prompt,
				"clip": ["34", 0]
			}
		}
		wf["38"]["inputs"]["negative"] = ["47", 0]
		wf.erase("46")
	return wf


func _build_upscale_workflow(filename: String) -> Dictionary:
	var wf = UPSCALE_ENHANCE_WORKFLOW_TEMPLATE.duplicate(true)
	wf["77"]["inputs"]["image"] = filename
	wf["87:81"]["inputs"]["scale_by"] = _upscale_factor / 4.0
	# Image directement depuis le LoadImage (pas de normalisation megapixels)
	wf["87:79"]["inputs"]["image"] = ["77", 0]
	# Sauvegarder la sortie de l'upscale (pas de VAEDecode)
	wf["9"]["inputs"]["images"] = ["87:81", 0]
	# Supprimer les nœuds enhance + normalisation
	for key in ["87:78", "87:66", "87:62", "87:63", "87:70", "87:67", "87:71", "87:80", "87:69", "87:65"]:
		wf.erase(key)
	return wf


func _build_enhance_workflow(filename: String, prompt_text: String, seed: int, cfg: float, steps: int, denoise: float, negative_prompt: String) -> Dictionary:
	var wf = UPSCALE_ENHANCE_WORKFLOW_TEMPLATE.duplicate(true)
	wf["77"]["inputs"]["image"] = filename
	wf["87:67"]["inputs"]["text"] = prompt_text
	wf["87:69"]["inputs"]["seed"] = seed
	wf["87:69"]["inputs"]["steps"] = steps
	wf["87:69"]["inputs"]["cfg"] = cfg
	wf["87:69"]["inputs"]["denoise"] = denoise
	wf["87:70"]["inputs"]["shift"] = _enhance_shift
	if negative_prompt.strip_edges() != "":
		wf["87:71"]["inputs"]["text"] = negative_prompt
	# Encoder l'image originale directement (pas d'upscale)
	wf["87:80"]["inputs"]["pixels"] = ["77", 0]
	# Supprimer les nœuds upscale
	for key in ["87:76", "87:78", "87:79", "87:81"]:
		wf.erase(key)
	return wf


func _build_upscale_enhance_workflow(filename: String, prompt_text: String, seed: int, cfg: float, steps: int, denoise: float, megapixels: float, negative_prompt: String) -> Dictionary:
	var wf = UPSCALE_ENHANCE_WORKFLOW_TEMPLATE.duplicate(true)
	wf["77"]["inputs"]["image"] = filename
	wf["87:81"]["inputs"]["scale_by"] = _upscale_factor / 4.0
	wf["87:78"]["inputs"]["megapixels"] = megapixels
	wf["87:67"]["inputs"]["text"] = prompt_text
	wf["87:69"]["inputs"]["seed"] = seed
	wf["87:69"]["inputs"]["steps"] = steps
	wf["87:69"]["inputs"]["cfg"] = cfg
	wf["87:69"]["inputs"]["denoise"] = denoise
	wf["87:70"]["inputs"]["shift"] = _enhance_shift
	if negative_prompt.strip_edges() != "":
		wf["87:71"]["inputs"]["text"] = negative_prompt
	return wf


func build_workflow(filename: String, prompt_text: String, seed: int, remove_background: bool = true, cfg: float = 1.0, steps: int = 4, workflow_type: int = WorkflowType.CREATION, denoise: float = 0.5, negative_prompt: String = "", face_box_size: int = 80, megapixels: float = 1.0, loras: Array = []) -> Dictionary:
	if workflow_type == WorkflowType.OUTPAINT:
		return _build_outpaint_workflow(filename, prompt_text, seed, cfg, steps, negative_prompt)
	if workflow_type == WorkflowType.UPSCALE:
		return _build_upscale_workflow(filename)
	if workflow_type == WorkflowType.ENHANCE:
		return _build_enhance_workflow(filename, prompt_text, seed, cfg, steps, denoise, negative_prompt)
	if workflow_type == WorkflowType.UPSCALE_ENHANCE:
		return _build_upscale_enhance_workflow(filename, prompt_text, seed, cfg, steps, denoise, megapixels, negative_prompt)
	if workflow_type == WorkflowType.BLINK:
		return _build_blink_workflow(filename, prompt_text, seed, remove_background, cfg, steps, denoise, negative_prompt, face_box_size, megapixels)
	if workflow_type == WorkflowType.EXPRESSION:
		return _build_expression_workflow(filename, prompt_text, seed, remove_background, cfg, steps, denoise, negative_prompt, face_box_size, megapixels)
	if workflow_type == WorkflowType.INPAINT:
		return _build_inpaint_workflow(filename, _mask_filename, prompt_text, seed, _inpaint_guidance, steps, denoise, negative_prompt, _mask_feather)
	var wf = WORKFLOW_TEMPLATE.duplicate(true)
	wf["76"]["inputs"]["image"] = filename
	wf["75:74"]["inputs"]["text"] = prompt_text
	wf["75:73"]["inputs"]["noise_seed"] = seed
	wf["75:63"]["inputs"]["cfg"] = cfg
	wf["75:62"]["inputs"]["steps"] = steps
	wf["75:80"]["inputs"]["megapixels"] = megapixels
	_apply_negative_prompt(wf, negative_prompt)
	_inject_loras(wf, loras)
	# Seconde image de référence pour Klein
	if _second_image_filename != "":
		wf["81"]["inputs"]["image"] = _second_image_filename
		wf["ref2_scale"] = {
			"class_type": "ImageScaleToTotalPixels",
			"inputs": {
				"upscale_method": "lanczos",
				"megapixels": megapixels,
				"resolution_steps": 1,
				"image": ["81", 0]
			}
		}
		wf["ref2_vae"] = {
			"class_type": "VAEEncode",
			"inputs": {
				"pixels": ["ref2_scale", 0],
				"vae": ["75:72", 0]
			}
		}
		wf["ref2_pos"] = {
			"class_type": "ReferenceLatent",
			"inputs": {
				"conditioning": ["75:79:77", 0],
				"latent": ["ref2_vae", 0]
			}
		}
		wf["ref2_neg"] = {
			"class_type": "ReferenceLatent",
			"inputs": {
				"conditioning": ["75:79:76", 0],
				"latent": ["ref2_vae", 0]
			}
		}
		wf["75:63"]["inputs"]["positive"] = ["ref2_pos", 0]
		wf["75:63"]["inputs"]["negative"] = ["ref2_neg", 0]
	else:
		wf.erase("81")
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


func _build_inpaint_workflow(filename: String, mask_filename: String, prompt_text: String, seed: int, guidance: float, steps: int, denoise: float, negative_prompt: String, mask_feather: int) -> Dictionary:
	var wf = INPAINT_FILL_WORKFLOW_TEMPLATE.duplicate(true)
	wf["17"]["inputs"]["image"] = filename
	wf["23"]["inputs"]["text"] = prompt_text
	wf["3"]["inputs"]["seed"] = seed
	wf["3"]["inputs"]["steps"] = steps
	wf["3"]["inputs"]["denoise"] = denoise
	wf["26"]["inputs"]["guidance"] = guidance

	wf["ip:mask"] = {
		"class_type": "LoadImage",
		"inputs": {"image": mask_filename}
	}
	wf["ip:mask_convert"] = {
		"class_type": "ImageToMask",
		"inputs": {"image": ["ip:mask", 0], "channel": "red"}
	}
	var final_mask_node: String
	if mask_feather <= 0:
		final_mask_node = "ip:mask_convert"
	else:
		wf["ip:grow"] = {
			"class_type": "GrowMask",
			"inputs": {"expand": mask_feather, "tapered_corners": true, "mask": ["ip:mask_convert", 0]}
		}
		var blur_kernel: int = min(99, max(3, mask_feather)) | 1
		var blur_sigma: float = minf(50.0, maxf(1.0, mask_feather * 0.5))
		wf["ip:blur"] = {
			"class_type": "ImpactGaussianBlurMask",
			"inputs": {"kernel_size": blur_kernel, "sigma": blur_sigma, "mask": ["ip:grow", 0]}
		}
		final_mask_node = "ip:blur"

	wf["38"]["inputs"]["mask"] = [final_mask_node, 0]

	if negative_prompt.strip_edges() != "":
		wf["47"] = {
			"class_type": "CLIPTextEncode",
			"inputs": {"text": negative_prompt, "clip": ["34", 0]}
		}
		wf["38"]["inputs"]["negative"] = ["47", 0]
		wf.erase("46")

	if _debug_mask:
		wf["debug_mask_to_image"] = {
			"class_type": "MaskToImage",
			"inputs": {"mask": [final_mask_node, 0]}
		}
		wf["9"]["inputs"]["images"] = ["debug_mask_to_image", 0]

	return wf


func _build_blink_workflow(filename: String, prompt_text: String, seed: int, remove_background: bool, cfg: float, steps: int, denoise: float = 0.5, negative_prompt: String = "", eye_expand: int = 15, megapixels: float = 1.0) -> Dictionary:
	var wf = EXPRESSION_WORKFLOW_TEMPLATE.duplicate(true)
	wf.erase("99")
	wf.erase("100")

	# --- Détection des yeux : BiSeNet ou YOLO ---
	var detect_image_ref = ["76", 0]
	if _detection_scale > 1.0:
		wf["fp_upscale"] = {
			"class_type": "ImageScaleBy",
			"inputs": {
				"image": ["76", 0],
				"upscale_method": "lanczos",
				"scale_by": _detection_scale
			}
		}
		detect_image_ref = ["fp_upscale", 0]

	var raw_mask_ref: Array  # référence vers le masque brut avant grow/blur
	if _detection_model == "bisenet":
		# BiSeNet face parsing
		wf["110"] = {
			"class_type": "FaceParsingLoader",
			"inputs": { "backbone": _backbone, "device": "auto" }
		}
		wf["111"] = {
			"class_type": "FaceParsingInfer",
			"inputs": {
				"image": detect_image_ref,
				"model": ["110", 0],
				"keep_resolution": true,
				"preview": false
			}
		}
		var part_inputs: Dictionary = { "seg_map": ["111", 0], "as_soft": false }
		if _eye_zone_mode == "eyes_and_brows":
			part_inputs["num_parts"] = 4
			part_inputs["part_1"] = "l_eye"
			part_inputs["part_2"] = "r_eye"
			part_inputs["part_3"] = "l_brow"
			part_inputs["part_4"] = "r_brow"
		else:
			part_inputs["num_parts"] = 2
			part_inputs["part_1"] = "l_eye"
			part_inputs["part_2"] = "r_eye"
		wf["112"] = { "class_type": "FacePartMask", "inputs": part_inputs }
		raw_mask_ref = ["112", 0]
	else:
		# YOLO eye detection (ultralytics .pt model)
		wf["99"] = {
			"class_type": "UltralyticsDetectorProvider",
			"inputs": { "model_name": "bbox/" + _detection_model }
		}
		wf["100"] = {
			"class_type": "BboxDetectorCombined_v2",
			"inputs": {
				"bbox_detector": ["99", 0],
				"image": detect_image_ref,
				"threshold": _detection_threshold,
				"dilation": 0
			}
		}
		raw_mask_ref = ["100", 0]

	# Si upscalé, rescaler le masque à la taille originale
	var mask_output_ref = raw_mask_ref
	if _detection_scale > 1.0:
		wf["fp_get_orig_size"] = {
			"class_type": "GetImageSize",
			"inputs": { "image": ["76", 0] }
		}
		wf["fp_mask_to_img"] = {
			"class_type": "MaskToImage",
			"inputs": { "mask": raw_mask_ref }
		}
		wf["fp_scale_mask"] = {
			"class_type": "ImageScale",
			"inputs": {
				"image": ["fp_mask_to_img", 0],
				"upscale_method": "lanczos",
				"width": ["fp_get_orig_size", 0],
				"height": ["fp_get_orig_size", 1],
				"crop": "disabled"
			}
		}
		wf["fp_img_to_mask"] = {
			"class_type": "ImageToMask",
			"inputs": { "image": ["fp_scale_mask", 0], "channel": "red" }
		}
		mask_output_ref = ["fp_img_to_mask", 0]
	# Rewire GrowMask vers le masque
	wf["101"]["inputs"]["mask"] = mask_output_ref
	wf["101"]["inputs"]["expand"] = eye_expand
	# Fondu masque contrôlé par _mask_feather (0 = bord dur, 100 = très doux)
	var final_mask_node: String
	if _mask_feather <= 0:
		# Pas de blur — supprimer le node et rewirer directement
		wf.erase("102")
		final_mask_node = "101"
	else:
		var blur_kernel: int = min(99, max(3, _mask_feather)) | 1  # impair, max 99
		var blur_sigma: float = minf(50.0, maxf(1.0, _mask_feather * 0.5))
		wf["102"]["inputs"]["kernel_size"] = blur_kernel
		wf["102"]["inputs"]["sigma"] = blur_sigma
		final_mask_node = "102"
	wf["103"]["inputs"]["mask"] = [final_mask_node, 0]
	wf["76"]["inputs"]["image"] = filename
	wf["75:74"]["inputs"]["text"] = prompt_text
	wf["75:73"]["inputs"]["noise_seed"] = seed
	wf["75:63"]["inputs"]["cfg"] = cfg
	wf["75:62"]["inputs"]["steps"] = steps
	wf["75:80"]["inputs"]["megapixels"] = megapixels
	_apply_negative_prompt(wf, negative_prompt)
	# img2img : partir de l'image source encodée avec masque de bruit
	# SetLatentNoiseMask : le KSampler ne dénoise QUE dans la zone masquée (yeux)
	# → pixel-perfect en dehors du masque
	wf["set_noise_mask"] = {
		"class_type": "SetLatentNoiseMask",
		"inputs": {
			"samples": ["75:79:78", 0],
			"mask": [final_mask_node, 0]
		}
	}
	wf["75:64"]["inputs"]["latent_image"] = ["set_noise_mask", 0]
	# SplitSigmas : contrôle du denoise
	var split_step = max(1, roundi(steps * (1.0 - denoise)))
	wf["split_sigmas"] = {
		"class_type": "SplitSigmas",
		"inputs": {
			"sigmas": ["75:62", 0],
			"step": split_step
		}
	}
	wf["75:64"]["inputs"]["sigmas"] = ["split_sigmas", 1]
	wf.erase("75:66")
	# Blink : toujours préserver l'alpha original de l'image source (pas de BiRefNet)
	# LoadImage (node 76) sortie 1 = canal alpha original
	# On recolle les yeux générés (node 103) avec l'alpha d'origine → pixel-perfect
	wf.erase("106")
	wf["join_alpha"] = {
		"class_type": "JoinImageWithAlpha",
		"inputs": {
			"image": ["103", 0],
			"alpha": ["76", 1]
		}
	}
	if _debug_mask:
		# Debug : exporter le masque en image au lieu du résultat
		wf["debug_mask_to_image"] = {
			"class_type": "MaskToImage",
			"inputs": { "mask": [final_mask_node, 0] }
		}
		wf["9"]["inputs"]["images"] = ["debug_mask_to_image", 0]
	else:
		wf["9"]["inputs"]["images"] = ["join_alpha", 0]
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
	# INPAINT bypass ReferenceLatent : 75:79:76 est absent, 75:83 est déjà câblé
	if wf.has("75:79:76"):
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

func generate_upscale_enhance(config: RefCounted, source_image_path: String, workflow_type: int, prompt_text: String, factor: float, denoise: float, steps: int, cfg: float, shift: float, megapixels: float, negative_prompt: String) -> void:
	if _generating:
		_fail("Une génération est déjà en cours")
		return

	_generating = true
	_cancelled = false
	_config = config
	_workflow_type = workflow_type
	_cfg = cfg
	_steps = steps
	_denoise = denoise
	_negative_prompt = negative_prompt
	_remove_background = false
	_megapixels = megapixels
	_loras = []
	_upscale_factor = factor
	_enhance_shift = shift

	generation_progress.emit("Chargement de l'image source...")

	var file = FileAccess.open(source_image_path, FileAccess.READ)
	if file == null:
		_generating = false
		_fail("Impossible d'ouvrir l'image : " + source_image_path)
		return

	var file_bytes = file.get_buffer(file.get_length())
	file.close()

	var filename = source_image_path.get_file()

	if _config.is_runpod():
		generation_progress.emit("Envoi vers RunPod...")
		_do_runpod_run(filename, file_bytes, prompt_text)
	else:
		generation_progress.emit("Upload de l'image vers ComfyUI...")
		_do_upload(filename, file_bytes, prompt_text)


func generate_outpaint(config: RefCounted, source_image_path: String, prompt_text: String, pad_left: int, pad_top: int, pad_right: int, pad_bottom: int, feathering: int, guidance: float, cfg: float, steps: int, negative_prompt: String) -> void:
	if _generating:
		_fail("Une génération est déjà en cours")
		return

	_generating = true
	_cancelled = false
	_config = config
	_workflow_type = WorkflowType.OUTPAINT
	_cfg = cfg
	_steps = steps
	_negative_prompt = negative_prompt
	_remove_background = false
	_denoise = 1.0
	_megapixels = 1.0
	_loras = []
	_outpaint_left = pad_left
	_outpaint_top = pad_top
	_outpaint_right = pad_right
	_outpaint_bottom = pad_bottom
	_outpaint_feathering = feathering
	_outpaint_guidance = guidance

	generation_progress.emit("Chargement de l'image source...")

	var file = FileAccess.open(source_image_path, FileAccess.READ)
	if file == null:
		_generating = false
		_fail("Impossible d'ouvrir l'image : " + source_image_path)
		return

	var file_bytes = file.get_buffer(file.get_length())
	file.close()

	var filename = source_image_path.get_file()

	if _config.is_runpod():
		generation_progress.emit("Envoi vers RunPod...")
		_do_runpod_run(filename, file_bytes, prompt_text)
	else:
		generation_progress.emit("Upload de l'image vers ComfyUI...")
		_do_upload(filename, file_bytes, prompt_text)


func generate_inpaint(config: RefCounted, source_image_path: String, prompt_text: String, mask_bytes: PackedByteArray, mask_feather: int, guidance: float, steps: int, denoise: float, negative_prompt: String) -> void:
	if _generating:
		_fail("Une génération est déjà en cours")
		return

	_generating = true
	_cancelled = false
	_config = config
	_workflow_type = WorkflowType.INPAINT
	_cfg = 1.0
	_steps = steps
	_denoise = denoise
	_negative_prompt = negative_prompt
	_remove_background = false
	_megapixels = 1.0
	_loras = []
	_inpaint_guidance = guidance
	_mask_filename = "inpaint_mask_%d.png" % randi()
	_mask_bytes_data = mask_bytes
	_mask_feather = mask_feather

	generation_progress.emit("Chargement de l'image source...")

	var file = FileAccess.open(source_image_path, FileAccess.READ)
	if file == null:
		_generating = false
		_fail("Impossible d'ouvrir l'image : " + source_image_path)
		return
	var file_bytes = file.get_buffer(file.get_length())
	file.close()
	var filename = source_image_path.get_file()
	_source_filename = filename

	if _config.is_runpod():
		generation_progress.emit("Envoi vers RunPod...")
		_do_runpod_run(filename, file_bytes, prompt_text)
	else:
		generation_progress.emit("Upload de l'image vers ComfyUI...")
		_do_upload(filename, file_bytes, prompt_text)


func generate(config: RefCounted, source_image_path: String, prompt_text: String, remove_background: bool = true, cfg: float = 1.0, steps: int = 4, workflow_type: int = WorkflowType.CREATION, denoise: float = 0.5, negative_prompt: String = "", face_box_size: int = 80, megapixels: float = 1.0, loras: Array = [], second_image_path: String = "", mask_bytes: PackedByteArray = PackedByteArray(), mask_feather: int = 15) -> void:
	if _generating:
		_fail("Une génération est déjà en cours")
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
	_megapixels = megapixels
	_loras = loras
	_second_image_filename = ""
	_second_image_bytes = PackedByteArray()
	_mask_filename = ""
	if not mask_bytes.is_empty():
		_mask_filename = "inpaint_mask_%d.png" % randi()
	_mask_bytes_data = mask_bytes
	_mask_feather = mask_feather

	generation_progress.emit("Chargement de l'image source...")

	# Load source image file bytes
	var file = FileAccess.open(source_image_path, FileAccess.READ)
	if file == null:
		_generating = false
		_fail("Impossible d'ouvrir l'image : " + source_image_path)
		return

	var file_bytes = file.get_buffer(file.get_length())
	file.close()

	var filename = source_image_path.get_file()
	_source_filename = filename

	# Load optional second image
	if second_image_path != "":
		var file2 = FileAccess.open(second_image_path, FileAccess.READ)
		if file2 != null:
			_second_image_bytes = file2.get_buffer(file2.get_length())
			file2.close()
			_second_image_filename = second_image_path.get_file()

	if _config.is_runpod():
		generation_progress.emit("Envoi vers RunPod...")
		_do_runpod_run(filename, file_bytes, prompt_text)
	else:
		generation_progress.emit("Upload de l'image vers ComfyUI...")
		_do_upload(filename, file_bytes, prompt_text)

func _do_runpod_run(filename: String, file_bytes: PackedByteArray, prompt_text: String) -> void:
	var seed = randi()
	var workflow = build_workflow(filename, prompt_text, seed, _remove_background, _cfg, _steps, _workflow_type, _denoise, _negative_prompt, _face_box_size, _megapixels, _loras)

	# --- DEBUG LOGS (même format que _do_prompt pour comparaison) ---
	var wt_name = WorkflowType.keys()[_workflow_type] if _workflow_type < WorkflowType.size() else str(_workflow_type)
	print("[RunPod] === RUN DEBUG ===")
	print("[RunPod] endpoint       : ", _config.get_url())
	print("[RunPod] workflow_type  : ", wt_name)
	print("[RunPod] image          : ", filename, " (", file_bytes.size(), " bytes)")
	print("[RunPod] prompt         : ", prompt_text)
	print("[RunPod] seed           : ", seed)
	print("[RunPod] cfg            : ", _cfg)
	print("[RunPod] steps          : ", _steps)
	print("[RunPod] denoise        : ", _denoise)
	print("[RunPod] megapixels     : ", _megapixels)
	print("[RunPod] remove_bg      : ", _remove_background)
	print("[RunPod] neg_prompt     : '", _negative_prompt, "'")
	if _mask_filename != "":
		print("[RunPod] mask           : ", _mask_filename, " (", _mask_bytes_data.size(), " bytes)")
	print("[RunPod] debug_mask     : ", _debug_mask)
	print("[RunPod] --- workflow JSON ---")
	print(JSON.stringify(workflow, "\t"))
	print("[RunPod] --- fin workflow ---")

	var image_b64 = Marshalls.raw_to_base64(file_bytes)
	var images_payload = [{"name": filename, "image": image_b64}]
	if _second_image_filename != "" and not _second_image_bytes.is_empty():
		images_payload.append({"name": _second_image_filename, "image": Marshalls.raw_to_base64(_second_image_bytes)})
	if _mask_filename != "" and not _mask_bytes_data.is_empty():
		images_payload.append({"name": _mask_filename, "image": Marshalls.raw_to_base64(_mask_bytes_data)})
	var payload = {
		"input": {
			"workflow": workflow,
			"images": images_payload
		}
	}

	var http = HTTPRequest.new()
	add_child(http)
	var url = _config.get_full_url("/run")
	var headers = PackedStringArray(["Content-Type: application/json"])
	for h in _config.get_auth_headers():
		headers.append(h)

	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		http.queue_free()
		if _cancelled:
			_generating = false
			return
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_generating = false
			_fail("Erreur RunPod /run (HTTP %d)" % code)
			return
		var resp = JSON.parse_string(body_bytes.get_string_from_utf8())
		if resp == null:
			_generating = false
			_fail("Réponse RunPod invalide")
			return
		var job_id: String = resp.get("id", "")
		if job_id == "":
			_generating = false
			_fail("Pas de job ID dans la réponse RunPod")
			return
		generation_progress.emit("Job RunPod soumis, traitement en cours...")
		_do_runpod_poll(job_id)
	)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))


func _do_runpod_poll(job_id: String) -> void:
	if _cancelled:
		_generating = false
		return

	var http = HTTPRequest.new()
	add_child(http)
	var url = _config.get_full_url("/status/" + job_id)

	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		http.queue_free()
		if _cancelled:
			_generating = false
			return
		if result != HTTPRequest.RESULT_SUCCESS:
			_generating = false
			_fail("Erreur polling RunPod")
			return
		var resp = JSON.parse_string(body_bytes.get_string_from_utf8())
		if resp == null:
			_generating = false
			_fail("Réponse statut RunPod invalide")
			return
		var status: String = resp.get("status", "")
		if status == "COMPLETED":
			var output = resp.get("output", {})
			if output == null:
				output = {}
			var images = output.get("images", [])
			if images.size() == 0:
				_generating = false
				_fail("Aucune image dans la sortie RunPod")
				return
			var b64: String = images[0].get("data", "")
			if b64 == "":
				_generating = false
				_fail("Image vide dans la sortie RunPod")
				return
			var image_bytes = Marshalls.base64_to_raw(b64)
			var image = Image.new()
			if image.load_png_from_buffer(image_bytes) != OK:
				_generating = false
				_fail("Impossible de décoder l'image RunPod")
				return
			_generating = false
			generation_completed.emit(image)
		elif status == "FAILED":
			_generating = false
			_fail("Job RunPod échoué : " + str(resp.get("error", "erreur inconnue")))
		else:
			generation_progress.emit("RunPod : " + status + "...")
			get_tree().create_timer(5.0).timeout.connect(func(): _do_runpod_poll(job_id))
	)
	http.request(url, _config.get_auth_headers(), HTTPClient.METHOD_GET)


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
			_fail("Erreur upload (code %d, result %d)" % [code, result])
			return
		if _second_image_filename != "" and not _second_image_bytes.is_empty():
			generation_progress.emit("Upload de l'image 2 vers ComfyUI...")
			_do_upload_second(prompt_text)
		elif _mask_filename != "" and not _mask_bytes_data.is_empty():
			generation_progress.emit("Upload du masque vers ComfyUI...")
			_do_upload_mask(prompt_text)
		else:
			generation_progress.emit("Image uploadée. Lancement du workflow...")
			_do_prompt(filename, prompt_text)
	)

	http.request_raw(url, PackedStringArray(headers), HTTPClient.METHOD_POST, body_bytes)

func _do_upload_second(prompt_text: String) -> void:
	var multipart = build_multipart_body(_second_image_filename, _second_image_bytes)
	var body_bytes: PackedByteArray = multipart[0]
	var boundary: String = multipart[1]

	var http = HTTPRequest.new()
	add_child(http)

	var url = _config.get_full_url("/upload/image")
	var headers: Array = ["Content-Type: multipart/form-data; boundary=" + boundary]
	for h in _config.get_auth_headers():
		headers.append(h)

	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray):
		http.queue_free()
		if _cancelled:
			_generating = false
			return
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_generating = false
			_fail("Erreur upload image 2 (code %d, result %d)" % [code, result])
			return
		if _mask_filename != "" and not _mask_bytes_data.is_empty():
			generation_progress.emit("Upload du masque vers ComfyUI...")
			_do_upload_mask(prompt_text)
		else:
			generation_progress.emit("Images uploadées. Lancement du workflow...")
			_do_prompt(_source_filename, prompt_text)
	)

	http.request_raw(url, PackedStringArray(headers), HTTPClient.METHOD_POST, body_bytes)


func _do_upload_mask(prompt_text: String) -> void:
	var multipart = build_multipart_body(_mask_filename, _mask_bytes_data)
	var body_bytes: PackedByteArray = multipart[0]
	var boundary: String = multipart[1]

	var http = HTTPRequest.new()
	add_child(http)

	var url = _config.get_full_url("/upload/image")
	var headers: Array = ["Content-Type: multipart/form-data; boundary=" + boundary]
	for h in _config.get_auth_headers():
		headers.append(h)

	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray):
		http.queue_free()
		if _cancelled:
			_generating = false
			return
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_generating = false
			_fail("Erreur upload masque (code %d, result %d)" % [code, result])
			return
		generation_progress.emit("Masque uploadé. Lancement du workflow...")
		_do_prompt(_source_filename, prompt_text)
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
	print("[ComfyUI] megapixels    : ", _megapixels)
	print("[ComfyUI] face_box_size : ", _face_box_size)
	print("[ComfyUI] neg_prompt    : '", _negative_prompt, "'")
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
			_fail("Erreur prompt (code %d) : %s" % [code, response_str.left(500)])
			return
		var response_str = body.get_string_from_utf8()
		_prompt_id = parse_prompt_response(response_str)
		if _prompt_id.is_empty():
			_generating = false
			_fail("Réponse invalide du serveur (pas de prompt_id)")
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
			_fail("Erreur workflow : %s" % error_msg)
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
			_fail("Erreur téléchargement (code %d)" % code)
			return
		print("[ComfyUI] received %d bytes" % body.size())
		var image = Image.new()
		var err = image.load_png_from_buffer(body)
		if err != OK:
			err = image.load_jpg_from_buffer(body)
		if err != OK:
			err = image.load_webp_from_buffer(body)
		if err != OK:
			_fail("Impossible de décoder l'image reçue")
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