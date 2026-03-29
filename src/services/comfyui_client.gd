extends Node

## Client HTTP pour ComfyUI. Gère upload, prompt, polling et download.

const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")

signal generation_completed(image: Image)
signal generation_failed(error: String)
signal generation_progress(status: String)

enum WorkflowType { CREATION = 0, EXPRESSION = 1, OUTPAINT = 2 }

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
var _outpaint_left: int = 0
var _outpaint_top: int = 0
var _outpaint_right: int = 0
var _outpaint_bottom: int = 0
var _outpaint_feathering: int = 24
var _outpaint_guidance: float = 40.0

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


func is_generating() -> bool:
	return _generating

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


func build_workflow(filename: String, prompt_text: String, seed: int, remove_background: bool = true, cfg: float = 1.0, steps: int = 4, workflow_type: int = WorkflowType.CREATION, denoise: float = 0.5, negative_prompt: String = "", face_box_size: int = 80, megapixels: float = 1.0, loras: Array = []) -> Dictionary:
	if workflow_type == WorkflowType.OUTPAINT:
		return _build_outpaint_workflow(filename, prompt_text, seed, cfg, steps, negative_prompt)
	if workflow_type == WorkflowType.EXPRESSION:
		return _build_expression_workflow(filename, prompt_text, seed, remove_background, cfg, steps, denoise, negative_prompt, face_box_size, megapixels)
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

func generate_outpaint(config: RefCounted, source_image_path: String, prompt_text: String, pad_left: int, pad_top: int, pad_right: int, pad_bottom: int, feathering: int, guidance: float, cfg: float, steps: int, negative_prompt: String) -> void:
	if _generating:
		generation_failed.emit("Une génération est déjà en cours")
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
		generation_failed.emit("Impossible d'ouvrir l'image : " + source_image_path)
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


func generate(config: RefCounted, source_image_path: String, prompt_text: String, remove_background: bool = true, cfg: float = 1.0, steps: int = 4, workflow_type: int = WorkflowType.CREATION, denoise: float = 0.5, negative_prompt: String = "", face_box_size: int = 80, megapixels: float = 1.0, loras: Array = []) -> void:
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
	print("[RunPod] --- workflow JSON ---")
	print(JSON.stringify(workflow, "\t"))
	print("[RunPod] --- fin workflow ---")

	var image_b64 = Marshalls.raw_to_base64(file_bytes)
	var payload = {
		"input": {
			"workflow": workflow,
			"images": [{"name": filename, "image": image_b64}]
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
			generation_failed.emit("Erreur RunPod /run (HTTP %d)" % code)
			return
		var resp = JSON.parse_string(body_bytes.get_string_from_utf8())
		if resp == null:
			_generating = false
			generation_failed.emit("Réponse RunPod invalide")
			return
		var job_id: String = resp.get("id", "")
		if job_id == "":
			_generating = false
			generation_failed.emit("Pas de job ID dans la réponse RunPod")
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
			generation_failed.emit("Erreur polling RunPod")
			return
		var resp = JSON.parse_string(body_bytes.get_string_from_utf8())
		if resp == null:
			_generating = false
			generation_failed.emit("Réponse statut RunPod invalide")
			return
		var status: String = resp.get("status", "")
		if status == "COMPLETED":
			var output = resp.get("output", {})
			if output == null:
				output = {}
			var images = output.get("images", [])
			if images.size() == 0:
				_generating = false
				generation_failed.emit("Aucune image dans la sortie RunPod")
				return
			var b64: String = images[0].get("data", "")
			if b64 == "":
				_generating = false
				generation_failed.emit("Image vide dans la sortie RunPod")
				return
			var image_bytes = Marshalls.base64_to_raw(b64)
			var image = Image.new()
			if image.load_png_from_buffer(image_bytes) != OK:
				_generating = false
				generation_failed.emit("Impossible de décoder l'image RunPod")
				return
			_generating = false
			generation_completed.emit(image)
		elif status == "FAILED":
			_generating = false
			generation_failed.emit("Job RunPod échoué : " + str(resp.get("error", "erreur inconnue")))
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
