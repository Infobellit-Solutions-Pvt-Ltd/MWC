
# Tokenizer Loading and Testing  

This script demonstrates how to load and test tokenizers from the **Hugging Face Transformers** library. It uses the `AutoTokenizer` class to load different tokenizers, tokenize sample text, and print the tokenized output.

## Requirements  

Ensure you have the `transformers` library installed:  

```bash
pip install transformers
```

## Usage  

The script loads tokenizers for two models:  

- **DeepSeek R1 Distill (1.5B)**  
- **Llama 3.2 (1B-Instruct)**  

It then tokenizes the word `"Hello"` using both tokenizers and prints the tokenized results.

### Code  

```python
from transformers import AutoTokenizer

# Load the tokenizers
ds_tokenizer = AutoTokenizer.from_pretrained("ds-rk1-1.5b")
llama_tokenizer = AutoTokenizer.from_pretrained("llama3.2-1b")

# Save the tokenizers to a directory (optional)
# ds_tokenizer.save_pretrained("ds-rk1-1.5b")
# llama_tokenizer.save_pretrained("llama3.2-1b")

# Tokenize and print results
print(ds_tokenizer("Hello"))
print(llama_tokenizer("Hello"))
```

### Expected Output  

The output will display tokenized representations of `"Hello"` for both tokenizers. The exact output may vary depending on the tokenizer's vocabulary.

### Customizing Tokenization  

To tokenize a longer sentence:  

```python
text = "Transformers are powerful for NLP."
print(ds_tokenizer(text))
print(llama_tokenizer(text))
```

### Saving the Tokenizer  

If you want to save the tokenizer locally for later use:  

```python
ds_tokenizer.save_pretrained("ds-rk1-1.5b")
llama_tokenizer.save_pretrained("llama3.2-1b")
```
