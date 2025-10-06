# Delcampe Postal Card Processor - Project Overview

## Purpose
The Delcampe Postal Card Processor is a Golem-based Shiny application designed for processing images uploaded by users. The app specializes in postal card/postcard processing for Delcampe posting, using LLM to extract meaningful information from images and send them to an API.

## Key Features
- **Image Upload & Processing**: Users can upload images of postal cards
- **Grid Detection**: Automatically detects grid layouts in images containing multiple postcards
- **Card Extraction**: Uses computer vision to extract individual postcards from grid layouts
- **Face/Verso Processing**: Handles both front (face) and back (verso) of postcards
- **LLM Integration**: Uses Large Language Models to extract meaningful information from postcards
- **API Integration**: Sends extracted information to external APIs

## Technical Approach
- **R-Python Integration**: Uses reticulate to bridge R Shiny UI with Python image processing
- **Computer Vision**: Leverages OpenCV for image processing, contour detection, and cropping
- **Modular Design**: Built on Golem framework following single responsibility principles
- **Golem Architecture**: Follows Golem guidelines for robust Shiny application development

## Business Context
This application serves the Delcampe marketplace by streamlining the process of listing postal cards, automatically extracting relevant information that would otherwise require manual entry.