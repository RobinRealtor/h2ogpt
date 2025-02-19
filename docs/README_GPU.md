# GPU Details

Hugging Face type models and [LLaMa.cpp models](https://github.com/ggerganov/llama.cpp#description) are supported via CUDA on Linux and via MPS on macOS.

To run in ChatBot mode using bitsandbytes in 8-bit, run the following command:
```bash
python generate.py --base_model=h2oai/h2ogpt-oig-oasst1-512-6_9b --load_8bit=True
```
Then point your browser at http://0.0.0.0:7860 (linux) or http://localhost:7860 (windows/mac) or the public live URL printed by the server (disable shared link with `--share=False`). Note that for 4-bit or 8-bit support, older GPUs may require older bitsandbytes installed as `pip uninstall bitsandbytes -y ; pip install bitsandbytes==0.38.1`.  For production uses, we recommend at least the 12B model, ran as:
```bash
python generate.py --base_model=h2oai/h2ogpt-oasst1-512-12b --load_8bit=True
```
and one can use `--h2ocolors=False` to get soft blue-gray colors instead of H2O.ai colors.  [Here](FAQ.md#what-envs-can-i-pass-to-control-h2ogpt) is a list of environment variables that can control some things in `generate.py`.

Note that if you download the model yourself and point `--base_model` to that location, you'll also need to specify the `prompt_type` by running:
```bash
python generate.py --base_model=<user path> --load_8bit=True --prompt_type=human_bot
```
for some user path `<user path>`. The `prompt_type` must match the model or a new version created in `prompter.py` or added in the UI/CLI via `prompt_dict`.

For quickly using a private document collection for Q/A, place documents (PDFs, text, etc.) into a folder called `user_path` and run the following command:
```bash
python generate.py --base_model=h2oai/h2ogpt-oig-oasst1-512-6_9b  --load_8bit=True --langchain_mode=UserData --user_path=user_path
```
For more details about document Q/A, see the [LangChain Readme](README_LangChain.md).

For 4-bit support when running `generate.py`, pass `--load_4bit=True`, which is only supported for certain [architectures](https://github.com/huggingface/peft#models-support-matrix) like GPT-NeoX-20B, GPT-J, LLaMa, etc.

Any other instruct-tuned base models can be used, including non-h2oGPT ones. Note that [larger models require more GPU memory](FAQ.md#larger-models-require-more-gpu-memory).

##### AutoGPTQ

**Important:** When running the following commands, if you encounter the message `CUDA extension not installed` during the loading of the model, you need to recompile. If you don't recompile, the generation will be significantly slower, even when using GPU.

An example with AutoGPTQ is:
```bash
python generate.py --base_model=TheBloke/Nous-Hermes-13B-GPTQ --score_model=None --load_gptq=model --use_safetensors=True --prompt_type=instruct --langchain_mode=UserData
```
This will use about 9800MB.  You can also add `--hf_embedding_model=sentence-transformers/all-MiniLM-L6-v2` to save some memory on embedding to reach 9340MB.

For LLaMa2 70B model quantized in 4-bit AutoGPTQ, you can run:
```bash
CUDA_VISIBLE_DEVICES=0 python generate.py --base_model=Llama-2-70B-chat-GPTQ --load_gptq="gptq_model-4bit--1g" --use_safetensors=True --prompt_type=llama2 --save_dir='save`
```
which gives about 12 tokens/sec.  For 7b run:
```bash
python generate.py --base_model=TheBloke/Llama-2-7b-Chat-GPTQ --load_gptq="model" --use_safetensors=True --prompt_type=llama2 --save_dir='save`
```
For full 16-bit with 16k context across all GPUs:
```bash
pip install transformers==4.31.0  # breaks load_in_8bit=True in some cases (https://github.com/huggingface/transformers/issues/25026)
python generate.py --base_model=meta-llama/Llama-2-70b-chat-hf --prompt_type=llama2 --rope_scaling="{'type': 'linear', 'factor': 4}" --use_gpu_id=False --save_dir=savemeta70b
```
and running on 4xA6000 gives about 4tokens/sec consuming about 35GB per GPU of 4 GPUs when idle.
Or for GPTQ with RoPE:
```bash
pip install transformers==4.31.0  # breaks load_in_8bit=True in some cases (https://github.com/huggingface/transformers/issues/25026)
python generate.py --base_model=TheBloke/Llama-2-7b-Chat-GPTQ --load_gptq="model" --use_safetensors=True --prompt_type=llama2 --score_model=None --save_dir='7bgptqrope4` --rope_scaling="{'type':'dynamic', 'factor':4}"
--max_max_new_tokens=15000 --max_new_tokens=15000 --max_time=12000
```
for which the GPU only uses 5.5GB.  One can add (e.g.) ` --min_new_tokens=4096` to force generation to continue beyond model's training norms, although this may give lower quality responses.
Currently, Hugging Face transformers does not support GPTQ directly except in text-generation-inference (TGI) server, but TGI does not support RoPE scaling.  Also, vLLM supports LLaMa2 and AutoGPTQ but not RoPE scaling.  Only exllama supports AutoGPTQ with RoPE scaling.

##### AutoAWQ

For 13B on 1 24GB board using about 14GB:
```bash
CUDA_VISIBLE_DEVICES=0 python generate.py --base_model=TheBloke/Llama-2-13B-chat-AWQ --score_model=None --load_awq=model --use_safetensors=True --prompt_type=llama2
```
or for 70B on 1 48GB board using about 39GB:
```bash
CUDA_VISIBLE_DEVICES=0 python generate.py --base_model=TheBloke/Llama-2-70B-chat-AWQ --score_model=None --load_awq=model --use_safetensors=True --prompt_type=llama2
```
or for 70B on 2 24GB boards:
```bash
CUDA_VISIBLE_DEVICES=2,3 python generate.py --base_model=TheBloke/Llama-2-70B-chat-AWQ --score_model=None --load_awq=model --use_safetensors=True --prompt_type=llama2
```

See [for more details](https://github.com/casper-hansen/AutoAWQ).

To run vLLM with 70B on 2 A100's using h2oGPT, follow the [vLLM install instructions](README_InferenceServers.md#vllm-inference-server-client) and then do:
```
python -m vllm.entrypoints.openai.api_server \
        --port=5000 \
        --host=0.0.0.0 \
        --model=h2oai/h2ogpt-4096-llama2-70b-chat-4bit \
        --tensor-parallel-size=2 \
        --seed 1234 \
        --trust-remote-code \
	    --max-num-batched-tokens 8192 \
	    --quantization awq \
        --download-dir=/$HOME/.cache/huggingface/hub
```
for choice of port, IP,  model, some number of GPUs matching tensor-parallel-size, etc.  Or with docker with built-in vLLM:
```bash
docker run -d \
    --runtime=nvidia \
    --gpus '"device=0,1"' \
    --shm-size=10.24gb \
    -p 5000:5000 \
    --entrypoint /h2ogpt_conda/vllm_env/bin/python3.10 \
    -e NCCL_IGNORE_DISABLED_P2P=1 \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -u `id -u`:`id -g` \
    -v "${HOME}"/.cache:/workspace/.cache \
    --network host \
    gcr.io/vorvan/h2oai/h2ogpt-runtime:0.1.0 -m vllm.entrypoints.openai.api_server \
        --port=5000 \
        --host=0.0.0.0 \
        --model=h2oai/h2ogpt-4096-llama2-70b-chat-4bit \
        --tensor-parallel-size=2 \
        --seed 1234 \
        --trust-remote-code \
	      --max-num-batched-tokens 8192 \
	      --quantization awq \
        --download-dir=/workspace/.cache/huggingface/hub &>> logs.vllm_server.70b_awq.txt
```
Can run same thing with 4 GPUs (to be safe) on 4*A10G like more available on AWS.

##### exllama

Currently, only [exllama](https://github.com/turboderp/exllama) supports AutoGPTQ with RoPE scaling.
To run RoPE scaling the LLaMa-2 7B model for 16k context:
```bash
python generate.py --base_model=TheBloke/Llama-2-7b-Chat-GPTQ --load_gptq="model" --use_safetensors=True --prompt_type=llama2 --save_dir='save' --load_exllama=True --revision=gptq-4bit-32g-actorder_True --rope_scaling="{'alpha_value':4}"
```
which shows how to control `alpha_value` and the `revision` for a given model on [TheBloke/Llama-2-7b-Chat-GPTQ](https://huggingface.co/TheBloke/Llama-2-7b-Chat-GPTQ).  Be careful as setting `alpha_value` higher consumes substantially more GPU memory.  Also, some models have incorrect config values for `max_position_embeddings` or `max_sequence_length`, and we try to fix those for LLaMa2 if `llama-2` appears in the lower-case version of the model name.
Another type of model is
```bash
python generate.py --base_model=TheBloke/Nous-Hermes-Llama2-GPTQ --load_gptq="model" --use_safetensors=True --prompt_type=llama2 --save_dir='save' --load_exllama=True --revision=gptq-4bit-32g-actorder_True --rope_scaling="{'alpha_value':4}"
```
and note the different `prompt_type`.  For LLaMa2 70B run:
```bash
python generate.py --base_model=TheBloke/Llama-2-70B-chat-GPTQ --load_gptq=gptq_model-4bit-128g --use_safetensors=True --prompt_type=llama2 --load_exllama=True --revision=main
```
which uses about 48GB of memory on 1 GPU and runs at about 12 tokens/second on an A6000, which is about half the speed of 16-bit if run that on 2*A100 GPUs.

With exllama, ensure `--concurrency_count=1` else the model will share states and mix-up concurrent requests.

You can set other exllama options by passing `--exllama_dict`. For example, for LLaMa-2-70B on 2 GPUs each using 20GB, you can run the following command:
```bash
python generate.py --base_model=TheBloke/Llama-2-70B-chat-GPTQ --load_exllama=True --use_safetensors=True --use_gpu_id=False --load_gptq=main --prompt_type=llama2 --exllama_dict="{'set_auto_map':'20,20'}"
```

##### For LLaMa.cpp on GPU run:
```bash
python generate.py --base_model='llama' --prompt_type=llama2 --score_model=None --langchain_mode='UserData' --user_path=user_path
```
and ensure that the output shows that one or more GPUs is in use. For example, for 1 GPU:
```text
ggml_init_cublas: found 1 CUDA devices:
  Device 0: NVIDIA GeForce RTX 3090 Ti, compute capability 8.6
llama_model_loader: loaded meta data with 19 key-value pairs and 291 tensors from llama-2-7b-chat.Q6_K.gguf (version GGUF V2 (latest))
...
... <bunch of tensor prints>
...
llm_load_print_meta: format           = GGUF V2 (latest)
llm_load_print_meta: arch             = llama
llm_load_print_meta: vocab type       = SPM
llm_load_print_meta: n_vocab          = 32000
llm_load_print_meta: n_merges         = 0
llm_load_print_meta: n_ctx_train      = 4096
llm_load_print_meta: n_embd           = 4096
llm_load_print_meta: n_head           = 32
llm_load_print_meta: n_head_kv        = 32
llm_load_print_meta: n_layer          = 32
llm_load_print_meta: n_rot            = 128
llm_load_print_meta: n_gqa            = 1
llm_load_print_meta: f_norm_eps       = 0.0e+00
llm_load_print_meta: f_norm_rms_eps   = 1.0e-06
llm_load_print_meta: n_ff             = 11008
llm_load_print_meta: freq_base_train  = 10000.0
llm_load_print_meta: freq_scale_train = 1
llm_load_print_meta: model type       = 7B
llm_load_print_meta: model ftype      = mostly Q6_K
llm_load_print_meta: model params     = 6.74 B
llm_load_print_meta: model size       = 5.15 GiB (6.56 BPW) 
llm_load_print_meta: general.name   = LLaMA v2
llm_load_print_meta: BOS token = 1 '<s>'
llm_load_print_meta: EOS token = 2 '</s>'
llm_load_print_meta: UNK token = 0 '<unk>'
llm_load_print_meta: LF token  = 13 '<0x0A>'
llm_load_tensors: ggml ctx size =    0.09 MB
llm_load_tensors: using CUDA for GPU acceleration
llm_load_tensors: mem required  =  102.63 MB
llm_load_tensors: offloading 32 repeating layers to GPU
llm_load_tensors: offloading non-repeating layers to GPU
llm_load_tensors: offloaded 35/35 layers to GPU
llm_load_tensors: VRAM used: 5169.80 MB
warning: failed to mlock 107520000-byte buffer (after previously locking 0 bytes): Cannot allocate memory
Try increasing RLIMIT_MLOCK ('ulimit -l' as root).
....................................................................................................
llama_new_context_with_model: n_ctx      = 4096
llama_new_context_with_model: freq_base  = 10000.0
llama_new_context_with_model: freq_scale = 1
llama_kv_cache_init: offloading v cache to GPU
llama_kv_cache_init: offloading k cache to GPU
llama_kv_cache_init: VRAM kv self = 2048.00 MB
llama_new_context_with_model: kv self size  = 2048.00 MB
llama_new_context_with_model: compute buffer total size = 581.88 MB
llama_new_context_with_model: VRAM scratch buffer: 576.01 MB
llama_new_context_with_model: total VRAM used: 7793.81 MB (model: 5169.80 MB, context: 2624.01 MB)
AVX = 1 | AVX2 = 1 | AVX512 = 0 | AVX512_VBMI = 0 | AVX512_VNNI = 0 | FMA = 1 | NEON = 0 | ARM_FMA = 0 | F16C = 1 | FP16_VA = 0 | WASM_SIMD = 0 | BLAS = 1 | SSE3 = 1 | SSSE3 = 1 | VSX = 0 | 
```
