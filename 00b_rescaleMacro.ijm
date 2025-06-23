// Single file version - this script will process a single user-selected file at the time

// ============== PARAMETERS TO SPECIFY BEFORE RUNNING THE SCRIPT: ==============

// Specify the channel that contains autofluorescence information: 
channel = 2;

// Specify the pixel size of the atlas (20 um/pix for the Perens atlas)
endPixelSize = 20;

// Specify the resolution level to start with (depends on initial resolution and endPixelSize)
resolutionLevel = 3;


// ============== CODE ==============

// Prompt the user to select an .ims file
filePath = File.openDialog("Choose an Imaris (.ims) file");

// Proceed only if a file was selected
if (endsWith(filePath, ".ims")) {
    run("Bio-Formats Importer", 
        "open=[" + filePath + "] " +
        "series_list=" + resolutionLevel + " " +
        "autoscale color_mode=Default view=Hyperstack stack_order=XYCZT quiet");
} else {
    showMessage("Invalid file type or no file selected.");
}

// Duplicate the selected channel and close the original one
originalImageName = getTitle();     // Gets the long name of the opened image - contains also info about resolution level, ...
run("Duplicate...", "title=processed duplicate channels=" + channel);
close(originalImageName);
selectImage("processed");

// Calculate rescaling factors based on current and end pixel size
getPixelSize(unit, pixelWidth, pixelHeight, voxelDepth);
rescaleXY = pixelWidth/endPixelSize;
rescaleZ = voxelDepth/endPixelSize;

// Rescale - change the number of pixels and their size
// NOTE: Total size of the image in um is preserved
run("Scale...", "x=" + rescaleXY + " y=" + rescaleXY + " z=" + rescaleZ + "interpolation=Bilinear average process create title=rescaled");
close("processed");

// Extract folder from file path and filename
lastSeparator = lastIndexOf(filePath, File.separator);
folder = substring(filePath, 0, lastSeparator + 1);
originalName = substring(filePath, lastSeparator + 1);
originalName = substring(originalName, 0, lengthOf(originalName) - 4);  // Remove ".ims"

// Construct save path and save
savePath = folder + "processed_" + originalName + ".tif";
saveAs("Tiff", savePath);