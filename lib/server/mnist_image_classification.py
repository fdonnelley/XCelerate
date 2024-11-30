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
from keras.models import Sequential, load_model
from keras.layers import Input, Dense, Conv2D, Dropout, Flatten, MaxPooling2D, BatchNormalization
from sklearn.metrics import confusion_matrix
import seaborn as sns
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from keras.preprocessing.image import load_img, img_to_array
from tensorflow.keras.optimizers import Adam
from keras.callbacks import ModelCheckpoint, EarlyStopping
import cv2
from keras.datasets import mnist
from IPython.display import clear_output
import os

from google.colab import drive
# drive.mount('/content/drive')

"""# Data"""

(x_train, y_train), (x_test, y_test) = mnist.load_data()

print(x_train.shape, y_train.shape)
print(x_test.shape, y_test.shape)

"""# Visualize Examples"""

def visualize_mnist_image(image, title='MNIST Image'):
  plt.figure(figsize=(10, 5))
  plt.title(title)
  plt.imshow(image, cmap='gray')
  plt.show()
  # [0, :, :, 0] - to undo reshaped image

num_classes = 10
f, ax = plt.subplots(1, num_classes, figsize=(20, 20))

for i in range(0, num_classes):
  sample = x_train[y_train == i][5]
  ax[i].imshow(sample, cmap='gray')
  ax[i].set_title("Label: {}".format(i), fontsize=16)

for i in range(10):
  print(y_train[i])

"""# Pre-Process Data"""

num_digits = 10
def pre_preocess_mnist_data(x_data, y_data):
  def convert_to_binary(image):
    blurred = cv2.GaussianBlur(image, (3, 3), 0)
    binary_full = cv2.adaptiveThreshold(
      image,
      255,
      cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
      cv2.THRESH_BINARY,
      blockSize=11,
      C=-4
    )
    return binary_full
  pre_processed_x_data = np.array(list(map(convert_to_binary, x_data)))
  pre_processed_x_data = pre_processed_x_data.reshape(pre_processed_x_data.shape[0], 28, 28, 1)
  pre_processed_y_data = keras.utils.to_categorical(y_data, num_digits)
  return pre_processed_x_data, pre_processed_y_data

x_train, y_train = pre_preocess_mnist_data(x_train, y_train)
x_test, y_test = pre_preocess_mnist_data(x_test, y_test)

print(x_train.shape)
print(y_train.shape)
print(x_test.shape)
print(y_test.shape)

"""# Augment Data"""

black_noise_percentage = 0.01
white_noise_percentage = 0.015

def add_noise(image):
  salt_pepper_mask = np.random.random(image.shape)
  image_with_noise = image.copy()

  # Salt noise (white pixels)
  image_with_noise[salt_pepper_mask < white_noise_percentage] = 255

  # Pepper noise (black pixels)
  image_with_noise[salt_pepper_mask > 1 - black_noise_percentage] = 0
  return image_with_noise

x_train = np.array(list(map(add_noise, x_train)))
x_test = np.array(list(map(add_noise, x_test)))

datagen = ImageDataGenerator(
  rotation_range = 5,  # randomly rotate images in the range (degrees, 0 to 180)
  zoom_range = 0.075, # Randomly zoom image
  width_shift_range = 0.075,  # randomly shift images horizontally (fraction of total width)
  height_shift_range = 0.075,  # randomly shift images vertically (fraction of total height)
)

times_to_augment = 8

# x_batch = next(datagen.flow(x_train[:8], y_train[:8], batch_size=times_to_augment, shuffle=False))[0]
# for image in x_batch:
#   visualize_mnist_image(image[:, :, 0])

augmented_images = []
augmented_labels = []

augmented_batch_gen = datagen.flow(x_train, y_train, batch_size=times_to_augment, shuffle=False)
for i in range(len(x_train)):
    augmented_x_batch, augmented_y_batch = next(augmented_batch_gen)
    augmented_images.extend(augmented_x_batch)
    augmented_labels.extend(augmented_y_batch)
    if(i+1)%1000 == 0:
      clear_output()
      print(f'{round((i+1)/len(x_train), 3)}% of data augmented')

# Convert lists to NumPy arrays
augmented_images = np.array(augmented_images)
augmented_labels = np.array(augmented_labels)

# Append augmented data to the original data
x_train = np.concatenate((x_train, augmented_images))
y_train = np.concatenate((y_train, augmented_labels))

print(augmented_images.shape)
print(augmented_labels.shape)
print(x_train.shape)
print(y_train.shape)

"""# Prepare Data"""

def proccess_data(data):
  data = (data == 255).astype(np.float32)
  return data

# def prepare_data(data, batch_size=times_to_augment):
#   for i in range(0, data.shape[0], batch_size):
#     batch = data[i:i+batch_size]

#     processed_batch = proccess_data(batch)

#     data[i:i+batch_size] = processed_batch
#   return data

# convert from integers to floats
x_train = proccess_data(x_train)
x_test = proccess_data(x_test)

"""# Create Model - Fully Connected Neural Network"""

model = Sequential()

# Input Layer
model.add(Input(shape=(28, 28, 1)))

# First Block
model.add(Conv2D(32, kernel_size=(3,3), kernel_initializer='he_uniform', activation='relu'))
model.add(BatchNormalization())
model.add(MaxPooling2D((2,2)))

# Second Block
model.add(Conv2D(64, kernel_size=(3, 3), activation='relu', padding='same', kernel_initializer='he_uniform'))
model.add(Conv2D(64, kernel_size=(3, 3), activation='relu', padding='same', kernel_initializer='he_uniform'))
model.add(BatchNormalization())
model.add(MaxPooling2D(pool_size=(2,2)))
model.add(Dropout(0.25))

# Third Block
model.add(Conv2D(64, kernel_size=(3, 3), activation='relu', padding='same', kernel_initializer='he_uniform'))
model.add(Conv2D(64, kernel_size=(3, 3), activation='relu', padding='same', kernel_initializer='he_uniform'))
model.add(BatchNormalization())
model.add(MaxPooling2D((2,2)))
model.add(Dropout(0.25))

# Fully Connected Layers
model.add(Flatten())
model.add(Dense(256, activation="relu", kernel_initializer='he_uniform'))
model.add(BatchNormalization())
model.add(Dropout(0.25))
model.add(Dense(128, activation="relu", kernel_initializer='he_uniform'))
model.add(BatchNormalization())
model.add(Dropout(0.25))

# Output Layer
model.add(Dense(10, activation="softmax"))

# Compile Model
model.compile(optimizer=Adam(learning_rate=0.001), loss=CategoricalCrossentropy(), metrics=['accuracy'])

model = load_model("/content/drive/MyDrive/MNIST Model/models/mnist_model.keras")
# model = load_model("/content/drive/MyDrive/MNIST Model/checkpoints/checkpoint_1.model.keras")
print(model.summary())

"""# Train Model"""

checkpoint_path = "/content/drive/MyDrive/MNIST Model/checkpoints/checkpoint_1.model.keras"
checkpoint_callback = ModelCheckpoint(
    filepath=checkpoint_path,
    monitor='val_loss',
    save_best_only=True,
    save_weights_only=False,
    verbose=1
)

early_stopping = EarlyStopping(
    monitor='val_loss',  # Monitor validation loss
    patience=5,          # Number of epochs with no improvement to wait before stopping
    restore_best_weights=True  # Roll back to the best model weights
)

history = model.fit(x=x_train, y=y_train, batch_size=32, epochs=20, validation_data=(x_test, y_test), callbacks=[early_stopping, checkpoint_callback])

"""# Evaluate Model"""

plt.plot(history.history['loss'])
plt.plot(history.history['val_loss'])
plt.title('Model loss')
plt.ylabel('Loss')
plt.xlabel('Epoch')
plt.legend(['Train', 'Validation'], loc='upper right')
plt.show()

plt.plot(history.history['accuracy'])
plt.plot(history.history['val_accuracy'])
plt.title('Model accuracy')
plt.ylabel('Accuracy')
plt.xlabel('Epoch')
plt.legend(['Train', 'Validation'], loc='lower right')
plt.show()

"""# Save Model"""

model.save("/content/drive/MyDrive/MNIST Model/models/mnist_model.keras")

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

def pre_process_image(image, debug=False):
  gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

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

def crop_image(image, debug=False):
  crop_width = min(200, image.shape[1]/3)
  if debug:
    blurred_image =  cv2.cvtColor(image, cv2.COLOR_BGR2RGB).copy()
    # Apply blur to left side
    blurred_image[:, :crop_width] = cv2.blur(image[:, :crop_width], (49, 49), 0)

    # Apply blur to right side
    blurred_image[:, -crop_width:] = cv2.blur(image[:, -crop_width:], (49, 49), 0)
    plt.figure(figsize=(10, 5))
    plt.title('Cropped Image')
    plt.imshow(blurred_image)
    plt.show()
  image = image[:, crop_width: -crop_width]
  return image

def process_image(image_path, debug=False):
    # Load and convert image
    original = cv2.imread(image_path)
    cropped_image = crop_image(original, debug=debug)
    pre_processed_image = pre_process_image(cropped_image, debug=debug)

    # Find Contours
    contours, _ = cv2.findContours(pre_processed_image, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    filtered_bounding_boxes = []
    for contour in contours:
      if filter_contour(contour, pre_processed_image, debug=debug):
        x, y, w, h = cv2.boundingRect(contour)
        filtered_bounding_boxes.append((x, y, w, h))
    digit_bounding_boxes = select_and_sort_bounding_boxes(filtered_bounding_boxes, debug=debug)
    if debug:
      contour_visualisation_image = cv2.cvtColor(cropped_image, cv2.COLOR_BGR2RGB).copy()
      for digit_bounding_box in digit_bounding_boxes:
        cv2.rectangle(
          contour_visualisation_image,
          (digit_bounding_box[0], digit_bounding_box[1]),
          (digit_bounding_box[0]+digit_bounding_box[2],
          digit_bounding_box[1]+digit_bounding_box[3]),
          (0, 255, 0),
          3
        )
      print(f"Found {len(digit_bounding_boxes)} digits")
      plt.figure(figsize=(10, 5))
      plt.title('Detected Digits')
      plt.imshow(contour_visualisation_image)
      plt.show()

    digit_images = []
    digit_selection_image = pre_processed_image.copy()
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
    return digit_images

"""# Image Prediction"""

image_dir = '/content/drive/MyDrive/MNIST Model/testing_images'
correct_predictions = 0
incorrect_predictions = 0
for filename in os.listdir(image_dir):
  filepath = os.path.join(image_dir, filename)
  if os.path.isfile(filepath):
    actual_digits = np.array(list(map(int, list(filename[:-7]))))
    digit_images = process_image(filepath, debug=False)
    predicted_digits, confidences = predict_digits_from_images(digit_images, debug=False)
    if np.array_equal(actual_digits, predicted_digits):
      correct_predictions += 1
    else:
      incorrect_predictions += 1

print('Incorrect predictions percentage:', round(incorrect_predictions / (correct_predictions + incorrect_predictions), 2))
print('Correct predictions percentage:', round(correct_predictions / (correct_predictions + incorrect_predictions), 2))
print('Incorrect predictions:', incorrect_predictions)
print('Correct predictions:', correct_predictions)

"""# TODO

*   make a pipeline to pass images thorugh to get digits
*   return both bounding boxes first, then digits
*   color the bounding boxes depending on certainty
"""