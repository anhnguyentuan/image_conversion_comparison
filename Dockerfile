FROM python:3.11-alpine

# Installs required package: ImageMagick, Tesseract OCR, OpenCV, Python libraries
RUN apk update && apk add --no-cache \
    bash perf parallel \
    ghostscript qpdf \
    imagemagick \
    poppler poppler-utils \
    vips-tools \
    libmagic \
    opencv-dev \
    build-base
# RUN pip install --no-cache-dir setuptools opencv-python-headless scikit-image

RUN yes 'will cite' | parallel --citation

WORKDIR /app
