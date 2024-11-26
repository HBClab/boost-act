# Base image with Python runtime
FROM python:3.10-slim

# Install R and essential tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-base \
    r-base-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    libssl-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container
WORKDIR /app

# Copy Python requirements file into the image
COPY requirements.txt /app/

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy R dependencies file (if any) into the image
COPY R_requirements.R /app/

# Install R dependencies
RUN python3 code/orchestrate.py -token {INSERT TOKEN HERE}
# Copy the rest of the application code into the image
COPY . /app/

# Define the default command to run the application
CMD ["python", "main.py"]
