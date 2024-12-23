# -*- coding: utf-8 -*-
"""MNIST Image Classification.ipynb

Automatically generated by Colab.

Original file is located at
    https://colab.research.google.com/drive/1dnV2fI1ApnNcpi2YAwjb9-q3halKkSyR

# Imports
"""

import numpy as np
import matplotlib.pyplot as plt
import keras
import tensorflow as tf
from tensorflow.keras.models import load_model
import cv2
import os
from flask import Flask, request, jsonify
import time

debug = False
save = False

def load_model_from_file(file_path):
  model_path = os.path.abspath(file_path)
  return load_model(model_path)

model = load_model_from_file("lib/server/models/mnist_model.keras")

app = Flask(__name__)
@app.route('/run-get_boxes', methods=['POST'])
def get_boxes():
  # Get the uploaded file
  # start_time = time.time()  # Start timing
  cv_image = get_uploaded_image_from_brga_bytes(request)
  # end_time = time.time()  # Stop timing
  # print("Time to retrive image:", end_time - start_time)
  # print("image size:", cv_image.shape)
  coordinates = get_digit_bounding_boxes(cv_image)
  scaledCoordinates = convert_to_percentage(coordinates, cv_image.shape[0], cv_image.shape[1])
  return jsonify({"coordinates": scaledCoordinates})


@app.route('/run-find_digits', methods=['POST'])
def find_digits():
  global save
  save = True
  # Get the uploaded file
  cv_image = get_uploaded_image(request)
  try:
    cv2.imwrite('uploaded_image.png', cv_image)
  except:
    pass
  # print("image size!!!!!:", cv_image.shape)
  result = predict_digits_from_picture(cv_image)
  print("result:", result)
  save = False
  return format_digits_and_confidences_to_response(result[0], result[1])

# Converts bounding box coordinates to percentages of the image height and width.
def convert_to_percentage(coordinates, img_height, img_width):
    if img_height == 0 or img_width == 0:
        raise ValueError("Image height and width must be greater than 0")

    percentage_coordinates = []

    crop_ajustment = 0.25

    for box in coordinates:
        x, y, width, height = box
        x_percent = (x / img_width) + crop_ajustment
        y_percent = y / img_height
        width_percent = width / img_width
        height_percent = height / img_height

        percentage_coordinates.append([
            round(x_percent, 4),
            round(y_percent, 4),
            round(width_percent, 4),
            round(height_percent, 4),
        ])

    return percentage_coordinates

# Retrieve and process the uploaded image from the request.
def get_uploaded_image(request):
  if 'image' not in request.files:
      return jsonify({"error": "No image uploaded"}), 400
  
  # start_time = time.time()  # Start timing for decoding
  file = request.files['image']
  file_bytes = file.read()
  # end_time = time.time()  # Stop timing for decoding
  # print("Time to read image:", end_time - start_time)

  # Convert bytes to an OpenCV image
  # start_time = time.time()  # Start timing for decoding
  nparr = np.frombuffer(file_bytes, dtype=np.uint8)
  # print("nparr size:", nparr.size)

  width = int(request.form['width'])
  height = int(request.form['height'])
  
  # print(f"Original array size: {nparr.size}, expected shape: ({height}, {width}, 4)")


  # nparr = nparr.reshape((height, width, 4))
  cv_image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)  # Use IMREAD_COLOR since we're sending PNG
  # cv_image = cv2.cvtColor(nparr, cv2.COLOR_BGR2RGB)
  # end_time = time.time()  # Stop timing for decoding
  # print("Time to decode image:", end_time - start_time)

  if cv_image is None:
      print("Failed to decode image. Input bytes length:", len(file_bytes))
      raise ValueError("Failed to decode image. Check the input bytes.")

  # Convert color format
  # start_time = time.time()  # Start timing for color conversion
  cv_image = cv2.cvtColor(cv_image, cv2.COLOR_RGBA2RGB)
  # end_time = time.time()  # Stop timing for color conversion
  # print("Time to convert color format:", end_time - start_time)

  # rotated_cv_image = cv2.rotate(cv_image, cv2.ROTATE_90_CLOCKWISE)


  # print("image size:", rotated_cv_image.shape)
  return cv_image

def get_uploaded_image_from_brga_bytes(request):
  if 'image' not in request.files:
      return jsonify({"error": "No image uploaded"}), 400
  
  # start_time = time.time()  # Start timing for decoding
  file = request.files['image']
  file_bytes = file.read()
  # end_time = time.time()  # Stop timing for decoding
  # print("Time to read image:", end_time - start_time)

  # Convert bytes to an OpenCV image
  # start_time = time.time()  # Start timing for decoding
  nparr = np.frombuffer(file_bytes, dtype=np.uint8)
  # Retrieve width and height from the request
  width = int(request.form['width'])
  height = int(request.form['height'])

  nparr = nparr.reshape((height, width, 4))
  # cv_image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)  # Use IMREAD_COLOR since we're sending PNG
  cv_image = cv2.cvtColor(nparr, cv2.COLOR_BGR2RGB)
  # end_time = time.time()  # Stop timing for decoding
  # print("Time to decode image:", end_time - start_time)

  if cv_image is None:
      print("Failed to decode image. Input bytes length:", len(file_bytes))
      raise ValueError("Failed to decode image. Check the input bytes.")

  # Convert color format
  # start_time = time.time()  # Start timing for color conversion
  cv_image = cv2.cvtColor(cv_image, cv2.COLOR_RGBA2RGB)
  # end_time = time.time()  # Stop timing for color conversion
  # print("Time to convert color format:", end_time - start_time)

  # print("image size:", cv_image.shape)
  return cv_image

# Format the predicted digits and their confidences into a JSON response.
def format_digits_and_confidences_to_response(digits, confidences):
  numbers_array_str = list(digits.astype(str))
  confidences_array_str = list(confidences.astype(str))
  number = ''.join(numbers_array_str)
  # print(confidences_array_str, number)
  return jsonify({"number": number, 'confidences': confidences_array_str})

"""# Visualize Examples"""
# Visualize a given MNIST image with a title.
def visualize_mnist_image(image, title='MNIST Image'):
  plt.figure(figsize=(10, 5))
  plt.title(title)
  plt.imshow(image, cmap='gray')
  plt.show()
  # [0, :, :, 0] - to undo reshaped image

"""# Prepare Data"""
# Process the input data to binary format.
def process_data(data):
  data = (data == 255).astype(np.float32)
  return data

"""# Digit Prediction"""
# Resize the input image array to maintain aspect ratio and fit into 28x28.
def resize_image(image_array):
  aspect_ratio = image_array.shape[1] / image_array.shape[0]
  if(aspect_ratio < 1):
    new_height = 28
    new_width = int(aspect_ratio * new_height)
  else:
    new_width = 28
    new_height = int(new_width / aspect_ratio)
  resized_image = cv2.resize(image_array, (new_width, new_height))

  # Calculate padding to make the image square (28x28)
  pad_width = (28 - new_width) // 2
  pad_height = (28 - new_height) // 2

  # Ensure padding is evenly distributed
  pad_width_left = pad_width_right = pad_width
  pad_height_top = pad_height_bottom = pad_height

  # Adjust for any off-by-one errors if 28 - new_width or 28 - new_height is odd
  if (28 - new_width) % 2 != 0:
      pad_width_right += 1
  if (28 - new_height) % 2 != 0:
      pad_height_bottom += 1
  padded_image = np.pad(resized_image, ((pad_height_top, pad_height_bottom), (pad_width_left, pad_width_right)), constant_values=0)
  return padded_image

# Predict digits from an array of images using the trained model.
def predict_digits_from_arrays(image_arrays):
  predictions = model.predict(image_arrays)
  digits = np.argmax(predictions, axis=1)
  confidences = np.max(predictions, axis=1)
  return digits, confidences

# Predict digits from a list of images after resizing and processing.
def predict_digits_from_images(images, debug=False):
  if not images:
    return None
  resized_images = np.array(list(map(resize_image, images)))
  # print("resized_images shape:", resized_images.shape)
  if debug:
    for resized_image in resized_images:
      visualize_mnist_image(resized_image)
  processed_images = process_data(resized_images)
  # print('processed_images shape:', processed_images.shape)
  processed_image_arrays = processed_images.reshape(processed_images.shape[0], 28, 28, 1)
  digits, confidences = predict_digits_from_arrays(processed_image_arrays)
  return digits, confidences

"""# Digit Seperation"""
# Sort bounding boxes based on their y-coordinate.
def sort_bounding_boxes(bounding_boxes):
  # Sort bounding boxes by y-coordinate
  bounding_boxes.sort(key=lambda x: x[1])
  return bounding_boxes

# Apply a blur effect to the left and right sides of the image.
def blur_image(image, blur_width):
  blurred_image =  image.copy()
  # Apply blur to left side
  blurred_image[:, :blur_width] = cv2.blur(image[:, :blur_width], (49, 49), 0)

  # Apply blur to right side
  blurred_image[:, -blur_width:] = cv2.blur(image[:, -blur_width:], (49, 49), 0)
  return blurred_image

# Crop the image to remove unnecessary parts based on the width.
def crop_image(image, debug=False):
  crop_width = int(image.shape[1]/4)
  if debug:
    plt.figure(figsize=(10, 5))
    plt.title('Blurred Image to show Crop')
    plt.imshow(blur_image(image, crop_width))
    plt.show()
  # print(image.shape)
  # print(crop_width)
  image = image[:, crop_width: -crop_width]
  return image

# Pre-process the image for digit recognition.
def pre_process_image(image, debug=False):
  # print(image.shape)
  cropped_image = crop_image(image, debug=debug)
  # print(image.shape)
  gray = cv2.cvtColor(cropped_image, cv2.COLOR_RGB2GRAY)
  # gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)

  # Step 1: Initial preprocessing with adaptive thresholding
  blurred = cv2.GaussianBlur(gray, (25, 25), 0)
  # blurred = cv2.fastNlMeansDenoising(gray, None, h=50, templateWindowSize=7, searchWindowSize=21)
  binary_full = cv2.adaptiveThreshold(
    blurred,
    255,
    cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
    cv2.THRESH_BINARY_INV,
    blockSize=41,
    C=5
  )

  # Apply morphological operations to connect components
  kernel = np.ones((5,5), np.uint8)
  binary_full_cleaned = cv2.morphologyEx(binary_full, cv2.MORPH_CLOSE, kernel, iterations=4)
  # kernel = np.ones((3,3), np.uint8)
  binary_full_cleaned = cv2.morphologyEx(binary_full_cleaned, cv2.MORPH_OPEN, kernel, iterations=1)

  if debug:
    plt.figure(figsize=(15, 5))
    plt.subplot(141)
    plt.title('Original')
    plt.imshow(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
    plt.subplot(142)
    plt.title('Blurred')
    plt.imshow(blurred, cmap='gray')
    plt.subplot(143)
    plt.title('Binary Full')
    plt.imshow(binary_full, cmap='gray')
    plt.show()
    plt.subplot(144)
    plt.title('Cleaned')
    plt.imshow(binary_full_cleaned, cmap='gray')
    plt.show()
  return binary_full_cleaned

# Filter contours based on area and aspect ratio criteria.
def filter_contour(contour, pre_processed_image, debug=False):
  min_contour_area = pre_processed_image.shape[0] / 14 * pre_processed_image.shape[1] / 14
  max_contour_area = pre_processed_image.shape[0] / 3 * pre_processed_image.shape[1] / 3
  min_contour_aspect_ratio = 0.9
  max_contour_aspect_ratio = 8.0
  contour_margin = 20
  contour_margins_max_white_threshold = 0.08 # Threshold for white pixels around the contour
  max_black_pixel_threshold = 0.95  # Max threshold for majority black pixels
  min_black_pixel_threshold = 0.3  # Min threshold for majority white pixels

  x, y, w, h = cv2.boundingRect(contour)
  area = w * h
  
  # Check area and aspect ratio
  if not (min_contour_area < area < max_contour_area):
      return False
  
  # aspect ratio check
  aspect_ratio = h / w if w > 0 else 0
  if not (min_contour_aspect_ratio < aspect_ratio < max_contour_aspect_ratio):
      return False
  
  contour_area = pre_processed_image[y:y+h, x:x+w]
  
  y_start = max(0, y - contour_margin)
  y_end = min(y + h + contour_margin, pre_processed_image.shape[0])
  x_start = max(0, x - contour_margin)
  x_end = min(x + w + contour_margin, pre_processed_image.shape[1])
  padded_contour_area = pre_processed_image[y_start:y_end, x_start:x_end]
  padded_contour_area_white_pixels = np.sum(padded_contour_area == 255)

  # Calculate the number of white and black pixels
  contour_area_white_pixels = np.sum(contour_area == 255)
  contour_area_black_pixels = np.sum(contour_area == 0)
  contour_area_total_pixels = contour_area.size
  
  # Calculate the percentage of white and black pixels
  black_percentage = contour_area_black_pixels / contour_area_total_pixels
  white_percentage = contour_area_white_pixels / contour_area_total_pixels
  
  # Calculate the percentage of white pixels in the margins around the contour
  margin_white_pixels = padded_contour_area_white_pixels - contour_area_white_pixels
  margin_total_pixels = padded_contour_area.size - contour_area_total_pixels
  
  margin_white_percentage = margin_white_pixels / margin_total_pixels if margin_total_pixels > 0 else 0

  # Check if the box contains predominantly black pixels or has an unusual amount of white pixels in the margin
  if margin_white_percentage < contour_margins_max_white_threshold and black_percentage < max_black_pixel_threshold and black_percentage > min_black_pixel_threshold:
    # print('contour area white percentage:', contour_area_white_pixels / contour_area_total_pixels)
    # print('margin_white_percentage:', margin_white_percentage)
    # print('black_percentage', black_percentage)
    # print('black_pixel_threshold', black_pixel_threshold)
    # print('white_percentage', white_percentage)
    # print('white_pixel_threshold', white_pixel_threshold)
    return True
  return False

# Select and sort bounding boxes based on validation criteria.
def select_and_sort_bounding_boxes(bounding_boxes, debug=False):
  sorted_bounding_boxes = sort_bounding_boxes(bounding_boxes)
  if validate_grouped_bounding_boxes(sorted_bounding_boxes):
    return sorted_bounding_boxes
  if debug:
    print('selecting bounding boxes')
  remaining_sorted_bounding_boxes = sorted_bounding_boxes.copy()
  bounding_box_groups = []
  while remaining_sorted_bounding_boxes:
    bounding_box_group = [remaining_sorted_bounding_boxes.pop(0)]
    for bounding_box in remaining_sorted_bounding_boxes:
      if validate_grouped_bounding_boxes(bounding_box_group + [bounding_box]):
        bounding_box_group.append(bounding_box)
    bounding_box_groups.append(bounding_box_group)
  return max(bounding_box_groups, key=len) if bounding_box_groups else []

# Validate if the grouped bounding boxes meet the area threshold.
def validate_grouped_bounding_boxes(bounding_box_group, area_threshold=0.4):
    if len(bounding_box_group) <= 1:
        return True

    # Calculate sum of individual contour areas
    total_bounding_box_area = sum([bounding_box[2] * bounding_box[3] for bounding_box in bounding_box_group])

    min_bounding_box_x = min(bounding_box[0] for bounding_box in bounding_box_group)
    min_bounding_box_y = min(bounding_box[1] for bounding_box in bounding_box_group)
    max_bounding_box_x = max(bounding_box[0] + bounding_box[2] for bounding_box in bounding_box_group)
    max_bounding_box_y = max(bounding_box[1] + bounding_box[3] for bounding_box in bounding_box_group)

    total_group_bounding_box_area = (max_bounding_box_x - min_bounding_box_x) * (max_bounding_box_y - min_bounding_box_y)

    # Calculate the ratio
    area_ratio = total_bounding_box_area / total_group_bounding_box_area
    # print('area_ratio:', area_ratio)

    return area_ratio >= area_threshold

# Get bounding boxes for digits in the provided image.
def get_digit_bounding_boxes(image):
  # start_time = time.time()  # Start timing
  pre_processed_image = pre_process_image(image)
  # end_time = time.time()  # End timing
  duration = end_time - start_time
  # print(f"get_digit_bounding_boxes took {duration:.4f} seconds")
  return extract_digit_bounding_boxes_from_processed_image(pre_processed_image, debug=False)

# Extract digit bounding boxes from a pre-processed image.
def extract_digit_bounding_boxes_from_processed_image(pre_processed_image, debug):
  # Find Contours
  contours, _ = cv2.findContours(pre_processed_image, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
  filtered_bounding_boxes = []
  for contour in contours:
    if filter_contour(contour, pre_processed_image, debug=debug):
      x, y, w, h = cv2.boundingRect(contour)
      filtered_bounding_boxes.append((x, y, w, h))
  # print("contours:", len(contours))
  # print('filtered_bounding_boxes:', filtered_bounding_boxes)
  bounding_boxes = select_and_sort_bounding_boxes(filtered_bounding_boxes, debug=debug)
  # print('bounding_boxes:', bounding_boxes)
  global save
  if save:
    # print('saving image with bounding boxes')
    try:
      cv2.imwrite('pre_processed_image_with_bounding_boxes.png', show_bounding_boxes_on_image(pre_processed_image, bounding_boxes))
    except:
      pass
  save = False
  return bounding_boxes

# Draw bounding boxes on the image for visualization.
def show_bounding_boxes_on_image(image, digit_bounding_boxes):
  display_image = image.copy()
  for digit_bounding_box in digit_bounding_boxes:
    cv2.rectangle(
      display_image,
      (digit_bounding_box[0], digit_bounding_box[1]),
      (digit_bounding_box[0]+digit_bounding_box[2],
      digit_bounding_box[1]+digit_bounding_box[3]),
      (0, 255, 0),
      3
    )
  return display_image

# Select individual digit images from the original image based on bounding boxes.
def select_digit_images_from_image(image, digit_bounding_boxes, debug=False):
  digit_images = []
  digit_selection_image = image.copy()
  for digit_bounding_box in digit_bounding_boxes:
    digit_padding = 5
    digit_image_min_x = max(digit_bounding_box[0] - digit_padding, 0)
    digit_image_min_y = max(digit_bounding_box[1] - digit_padding, 0)
    digit_image_max_x = min(digit_bounding_box[0] + digit_bounding_box[2] + digit_padding, digit_selection_image.shape[1])
    digit_image_max_y = min(digit_bounding_box[1] + digit_bounding_box[3] + digit_padding, digit_selection_image.shape[0])
    digit_image = digit_selection_image[digit_image_min_y:digit_image_max_y, digit_image_min_x:digit_image_max_x]
    digit_images.append(digit_image)
    if debug:
      plt.figure(figsize=(4, 2))
      plt.title('Detected Digit')
      plt.imshow(digit_image, cmap='gray')
      plt.show()
  return digit_images

# Process the image to extract digit images and their bounding boxes.
def process_image(image, debug=False):
    pre_processed_image = pre_process_image(image, debug=debug)
    cv2.imwrite('pre_processed_prediction_image.png', pre_processed_image)

    digit_bounding_boxes = extract_digit_bounding_boxes_from_processed_image(pre_processed_image, debug=debug)
    return select_digit_images_from_image(pre_processed_image, digit_bounding_boxes, debug)

# Predict digits from a given image using the processing pipeline.
def predict_digits_from_picture(cv2_image):
  digit_images = process_image(cv2_image, debug=False)
  return predict_digits_from_images(digit_images, debug=False)

if __name__ == '__main__':
    print("Server started")
    app.run(debug=True, host='0.0.0.0', port=5001)
