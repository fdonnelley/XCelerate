# -*- coding: utf-8 -*-
"""MNIST Image Classification.ipynb

Automatically generated by Colab.

Original file is located at
    https://colab.research.google.com/drive/1dnV2fI1ApnNcpi2YAwjb9-q3halKkSyR

# Imports
"""

# Commented out IPython magic to ensure Python compatibility.
import numpy as np
import matplotlib.pyplot as plt
# %matplotlib inline
import keras
import tensorflow as tf
from tensorflow.keras.models import load_model
# from keras.layers import Input, Dense, Conv2D, Dropout, Flatten, MaxPooling2D, BatchNormalization
# from sklearn.metrics import confusion_matrix
# import seaborn as sns
# from tensorflow.keras.preprocessing.image import ImageDataGenerator
# from keras.preprocessing.image import load_img, img_to_array
# from tensorflow.keras.optimizers import Adam
# from keras.callbacks import ModelCheckpoint, EarlyStopping
import cv2
# from keras.datasets import mnist
# from IPython.display import clear_output
import os
from flask import Flask, request, jsonify

app = Flask(__name__)
@app.route('/run-get_boxes', methods=['POST'])
def get_boxes():
  # Get the uploaded file
  cv_image = get_uploaded_image(request)
  return get_digit_bounding_boxes(cv_image)


@app.route('/run-predict_digits_from_picture', methods=['POST'])
def run_function():
  # Get the uploaded file
  cv_image = get_uploaded_image(request)
  result = predict_digits_from_picture(cv_image)
  print("result:", result)
  return format_digits_and_confidences_to_response(result[0], result[1])


def get_uploaded_image(request):
  if 'image' not in request.files:
      return jsonify({"error": "No image uploaded"}), 400
  
  file = request.files['image']
  file_bytes = file.read()

  # Convert bytes to an OpenCV image
  nparr = np.frombuffer(file_bytes, np.uint8)
  cv_image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
  return cv2.cvtColor(cv_image, cv2.COLOR_BGR2RGB)

def format_digits_and_confidences_to_response(digits, confidences):
  numbers_array_str = list(digits.astype(str))
  confidences_array_str = list(confidences.astype(str))
  number = ''.join(numbers_array_str)
  print(confidences_array_str, number)
  return jsonify({"number": number, 'confidences': confidences_array_str})
"""# Visualize Examples"""

def visualize_mnist_image(image, title='MNIST Image'):
  plt.figure(figsize=(10, 5))
  plt.title(title)
  plt.imshow(image, cmap='gray')
  plt.show()
  # [0, :, :, 0] - to undo reshaped image

"""# Prepare Data"""

def proccess_data(data):
  data = (data == 255).astype(np.float32)
  return data

"""# Digit Prediction"""

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

def predict_digits_from_arrays(image_arrays):
  model_path = os.path.abspath("lib/server/models/mnist_model.keras")
  model = load_model(model_path)
  # model = load_model("models/mnist_model.keras")
  # model = load_model("/content/drive/MyDrive/MNIST Model/checkpoints/checkpoint_1.model.keras")
  print(model.summary())
  predictions = model.predict(image_arrays)
  digits = np.argmax(predictions, axis=1)
  confidences = np.max(predictions, axis=1)
  return digits, confidences

def predict_digits_from_images(image, debug=False):
  resized_images = np.array(list(map(resize_image, image)))
  if debug:
    for resized_image in resized_images:
      visualize_mnist_image(resized_image)
  proccessed_images = proccess_data(resized_images)
  proccessed_image_arrays = proccessed_images.reshape(proccessed_images.shape[0], 28, 28, 1)
  digits, confidences = predict_digits_from_arrays(proccessed_image_arrays)
  return digits, confidences

"""# Digit Seperation"""

def sort_bounding_boxes(bounding_boxes):
  # Sort bounding boxes by y-coordinate
  bounding_boxes.sort(key=lambda x: x[1])
  return bounding_boxes

def blur_image(image, blur_width):
  blurred_image =  image.copy()
  # Apply blur to left side
  blurred_image[:, :blur_width] = cv2.blur(image[:, :blur_width], (49, 49), 0)

  # Apply blur to right side
  blurred_image[:, -blur_width:] = cv2.blur(image[:, -blur_width:], (49, 49), 0)
  return blurred_image

def crop_image(image, debug=False):
  crop_width = min(200, image.shape[1]/3)
  if debug:
    plt.figure(figsize=(10, 5))
    plt.title('Blurred Image to show Crop')
    plt.imshow(blur_image(image.copy(), crop_width))
    plt.show()
  image = image[:, crop_width: -crop_width]
  return image

def pre_process_image(image, debug=False):
  cropped_image = crop_image(image, debug=debug)
  gray = cv2.cvtColor(cropped_image, cv2.COLOR_RGB2GRAY)

  # Step 1: Initial preprocessing with adaptive thresholding instead of Otsu
  blurred = cv2.GaussianBlur(gray, (5, 5), 0)
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
  binary_full = cv2.dilate(binary_full, kernel, iterations=1)
  binary_full = cv2.erode(binary_full, kernel, iterations=1)
  kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))  # Kernel size determines removal size
  binary_full_cleaned = cv2.morphologyEx(binary_full, cv2.MORPH_OPEN, kernel)

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

def filter_contour(contour, pre_processed_image, debug=False):
  min_contour_area = 800
  max_contour_area = pre_processed_image.shape[0] / 3 * pre_processed_image.shape[1] / 3
  min_contour_aspect_ratio = 0.8
  max_contour_aspect_ratio = 8.0
  contour_margin = 20
  contour_margins_max_white_threshold = 0.09
  contour_area_min_white_threshold = 0.3
  contour_area_max_white_threshold = 0.7

  x, y, w, h = cv2.boundingRect(contour)
  area = w * h
  if min_contour_area < area < max_contour_area:
    # aspect ratio check
    aspect_ratio = h / w if w > 0 else 0
    if min_contour_aspect_ratio < aspect_ratio < max_contour_aspect_ratio:
      # print(f'x: {x}. y: {y}. w: {w}. h: {h}')
      y_start = max(0, y - contour_margin)
      y_end = min(y + h + contour_margin, pre_processed_image.shape[0])
      x_start = max(0, x - contour_margin)
      x_end = min(x + w + contour_margin, pre_processed_image.shape[1])
      padded_contour_area = pre_processed_image[y_start:y_end, x_start:x_end]
      contour_area = pre_processed_image[y:y+h, x:x+w]
      padded_contour_area_white_pixels = np.sum(padded_contour_area == 255)
      padded_contour_area_total_pixels = padded_contour_area.size
      contour_area_white_pixels = np.sum(contour_area == 255)
      contour_area_total_pixels = contour_area.size

      margin_white_pixels = padded_contour_area_white_pixels - contour_area_white_pixels
      margin_total_pixels = padded_contour_area_total_pixels - contour_area_total_pixels
      if margin_total_pixels != 0:
        white_percentage = margin_white_pixels / margin_total_pixels
      else:
        white_percentage = 0
        # print('area:', area)
        # print('max_contour_area:', max_contour_area)
        # print(f'x: {x}. y: {y}. w: {w}. h: {h}')
        # print('contour:', contour)
      # print('white_percentage:', white_percentage)
      if white_percentage < contour_margins_max_white_threshold:
        # print('contour area white percentage:', contour_area_white_pixels / contour_area_total_pixels)
        # print('white_percentage:', white_percentage)
        return True
  return False

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
  return max(bounding_box_groups, key=len)

def validate_grouped_bounding_boxes(bounding_box_group, area_threshold=0.5):
    if len(bounding_box_group) == 1:
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

def get_digit_bounding_boxes(image):
  pre_processed_image = pre_process_image(image)
  return get_digit_bounding_boxes_from_processed_image(pre_processed_image, debug=False)


def get_digit_bounding_boxes_from_processed_image(pre_processed_image, debug):
  # Find Contours
  contours, _ = cv2.findContours(pre_processed_image, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
  filtered_bounding_boxes = []
  for contour in contours:
    if filter_contour(contour, pre_processed_image, debug=debug):
      x, y, w, h = cv2.boundingRect(contour)
      filtered_bounding_boxes.append((x, y, w, h))
  return select_and_sort_bounding_boxes(filtered_bounding_boxes, debug=debug)

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
      plt.imshow(digit_image.copy(), cmap='gray')
      plt.show()

def process_image(image, debug=False):
    pre_processed_image = pre_process_image(image, debug=debug)
    digit_bounding_boxes = get_digit_bounding_boxes_from_processed_image(pre_processed_image, debug=debug)
    return select_digit_images_from_image(pre_processed_image, digit_bounding_boxes, debug)

def predict_digits_from_picture(cv2_image):
  digit_images = process_image(cv2_image, debug=False)
  return predict_digits_from_images(digit_images, debug=False)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5001)
