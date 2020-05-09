# Object Dimensioner
Object Dimensioner implemented on iOS with OpenCV.
With this utility you can measure any object using image processing.

## Installation

After cloning, run the following:
```bash
carthage update
````
## How to use the app
#### 1. Calibrate the camera by pointing the camera to a printed version of the following document: https://nerian.com/support/resources/patterns/
<kbd>
  <img src="IMG_5179.JPG"/>
</kbd>

#### 2. You need a monochromatic background to apply a chroma-key effect. Point the camera to the background. This will give you the colors. Select which ones you want to use apply the chroma-key effect.
<kbd>
    <img src="IMG_5180.JPG"/>
</kbd>

#### 3. Place two objects on the scene. On the left, place an object which you know the measurements
<kbd>
    <img src="IMG_5178.JPG"/>
</kbd>

#### 4. Inform the real dimensions for this object and confirm

#### 5. Adjust Brightness and Saturation

#### 6. Adjust the object detection threshold


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
