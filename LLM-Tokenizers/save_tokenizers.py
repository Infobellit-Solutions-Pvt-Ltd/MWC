from transformers import AutoTokenizer

# Load a tokenizer (example: BERT tokenizer)
#ds_tokenizer = AutoTokenizer.from_pretrained("deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B")
ds_tokenizer = AutoTokenizer.from_pretrained("ds-rk1-1.5b")
#llama_tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.2-1B-Instruct")
llama_tokenizer = AutoTokenizer.from_pretrained("llama3.2-1b")

# Save the tokenizer to a directory
#ds_tokenizer.save_pretrained("ds-rk1-1.5b")
#llama_tokenizer.save_pretrained("llama3.2-1b")

print(ds_tokenizer("Hello"))
print(llama_tokenizer("Hello"))
