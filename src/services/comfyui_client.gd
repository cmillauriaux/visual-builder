extends Node

## Client HTTP pour ComfyUI. Gère upload, prompt, polling et download.

const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")

signal generation_completed(image: Image)
signal generation_failed(error: String)
signal generation_progress(status: String)

enum WorkflowType { CREATION = 0, EXPRESSION = 1, UPSCALE = 2 }

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


func build_workflow(filename: String, prompt_text: String, seed: int, remove_background: bool = true, cfg: float = 1.0, steps: int = 4, workflow_type: int = WorkflowType.CREATION, denoise: float = 0.5, negative_prompt: String = "", face_box_size: int = 80) -> Dictionary:
	if workflow_type == WorkflowType.UPSCALE:
		return _build_upscale_workflow(filename, prompt_text, seed, denoise, _upscale_model_name, _upscale_tile_size, _upscale_target_w, _upscale_target_h, negative_prompt)
	if workflow_type == WorkflowType.EXPRESSION:
		return _build_expression_workflow(filename, prompt_text, seed, remove_background, cfg, steps, denoise, negative_prompt, face_box_size)
	var wf = WORKFLOW_TEMPLATE.duplicate(true)
	wf["76"]["inputs"]["image"] = filename
	wf["75:74"]["inputs"]["text"] = prompt_text
	wf["75:73"]["inputs"]["noise_seed"] = seed
	wf["75:63"]["inputs"]["cfg"] = cfg
	wf["75:62"]["inputs"]["steps"] = steps
	_apply_negative_prompt(wf, negative_prompt)
	if not remove_background:
		# Pour les backgrounds : sauvegarder directement la sortie du VAEDecode
		# sans passer par BiRefNetRMBG (pas de suppression de fond)
		wf["9"]["inputs"]["images"] = ["75:65", 0]
		wf.erase("100")
	return wf

func _build_expression_workflow(filename: String, prompt_text: String, seed: int, remove_background: bool, cfg: float, steps: int, denoise: float = 0.5, negative_prompt: String = "", face_box_size: int = 80) -> Dictionary:
	var wf = EXPRESSION_WORKFLOW_TEMPLATE.duplicate(true)
	# Appliquer la taille de la zone visage (dilation + expand)
	wf["100"]["inputs"]["dilation"] = face_box_size
	wf["101"]["inputs"]["expand"] = face_box_size
	wf["76"]["inputs"]["image"] = filename
	wf["75:74"]["inputs"]["text"] = prompt_text
	wf["75:73"]["inputs"]["noise_seed"] = seed
	wf["75:63"]["inputs"]["cfg"] = cfg
	wf["75:62"]["inputs"]["steps"] = steps
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
	# Find the output node with images
	var outputs = entry["outputs"]
	for node_id in outputs:
		var node_output = outputs[node_id]
		if node_output is Dictionary and node_output.has("images"):
			var images = node_output["images"]
			if images is Array and images.size() > 0:
				return {"status": "completed", "filename": images[0]["filename"]}
	return {"status": "error", "error": "Aucune image dans les sorties"}

# --- Full generation flow ---

func generate(config: RefCounted, source_image_path: String, prompt_text: String, remove_background: bool = true, cfg: float = 1.0, steps: int = 4, workflow_type: int = WorkflowType.CREATION, denoise: float = 0.5, negative_prompt: String = "", face_box_size: int = 80, upscale_model_name: String = "4x-UltraSharp.pth", tile_size: int = 512, target_w: int = 0, target_h: int = 0) -> void:
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
	var workflow = build_workflow(filename, prompt_text, seed, _remove_background, _cfg, _steps, _workflow_type, _denoise, _negative_prompt, _face_box_size)
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
