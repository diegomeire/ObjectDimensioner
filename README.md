# Object Dimensioner
Object Dimensioner implemented on iOS with OpenCV.
With this utility you can measure any object using image processing.
This app works on three steps: 
#### 1- Subsitute a background color with white (chrome key)
#### 2- Find the contours of object on the screen
#### 3- Given the dimensions of an known object it will calculate the dimensions of another

## Installation

After cloning, run the following:
```bash
carthage update
````
## How to use the app
#### 1. Camera Calibration
##### Calibrate the camera by pointing the camera to a printed version of the following document: https://nerian.com/support/resources/patterns/
<kbd>
  <img src="CalibrateCamera.gif"/>
</kbd>

#### 2. Set the background 
##### You need a monochromatic background to apply a chroma-key effect. Point the camera to the background. This will give you the colors. Select which ones you want to use apply the chroma-key effect.
<kbd>
    <img src="GetColors.gif"/>
</kbd>

#### 3. Adjust Brightness and Saturation
<kbd>
    <img src="ApplyChromaKey.gif"/>
</kbd>

#### 4. Adjust the object detection threshold


#### 3. Place two objects on the scene. On the left, place an object which you know the measurements
<kbd>
    <img src="IMG_5178.JPG"/>
</kbd>

#### 4. Inform the real dimensions for this object and confirm





#### 7. Get the dimensions for the object on the right






#### Have fun!

<kbd>
      <img src="InvisibleCloak.gif"/>
</kbd>


## Thanks

#### This project was possible thanks to previous projects such as the following:
##### https://github.com/thorikawa/camera-calibration-ios (Takahiro "Poly" Horikawa)

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License
[MIT](https://choosealicense.com/licenses/mit/)
