# Use an official Python image
FROM python:3.10-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the project files into the container
COPY power_metrics/ power_metrics/

# Set up a virtual environment and install dependencies
RUN python -m venv /app/venv && \
    /app/venv/bin/pip install --upgrade pip && \
    /app/venv/bin/pip install -r power_metrics/requirements.txt

# Expose the Flask API port
EXPOSE 5000

# Set the entrypoint to allow dynamic file argument
ENTRYPOINT ["/app/venv/bin/python", "power_metrics/pub_power_metrics.py"]
