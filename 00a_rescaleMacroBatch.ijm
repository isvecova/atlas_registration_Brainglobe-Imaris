// Batch version - this script will process all .ims files in a user-selected folder

// ============== PARAMETERS TO SPECIFY BEFORE RUNNING THE SCRIPT: ==============

// Specify the channel that contains autofluorescence information: 
channel = 2;

// Specify the pixel size of the atlas (20 um/pix for the Perens atlas)
endPixelSize = 20;

// Specify the resolution level to start with (depends on initial resolution and endPixelSize)
resolutionLevel = 3;


// ============== CODE ==============

// Prompt user to select folder
folder = getDirectory("Choose folder with .ims files");

// Get list of all files in folder
list = getFileList(folder);

// Loop through files
for (i = 0; i < list.length; i++) {
    
    if (endsWith(list[i], ".ims")) {
        
        filePath = folder + list[i];
        print("Processing: " + filePath);
        
        // Open specified resolution level
        run("Bio-Formats Importer", 
            "open=[" + filePath + "] " +
            "series_list=" + resolutionLevel + " " +
            "autoscale color_mode=Default view=Hyperstack stack_order=XYCZT quiet");
        
        // Duplicate selected channel
        longImageName = getTitle(); // Might contain "..." in GUI
        run("Duplicate...", "title=processed duplicate channels=" + channel);
        close(longImageName);
        selectImage("processed");
        
        // Calculate rescaling factors based on current and end pixel size
        getPixelSize(unit, pixelWidth, pixelHeight, voxelDepth);
        rescaleXY = pixelWidth / endPixelSize;
        rescaleZ = voxelDepth / endPixelSize;
        
        // Rescale - change the number of pixels and their size
        // NOTE: Total size of the image in um is preserved
        run("Scale...", "x=" + rescaleXY + " y=" + rescaleXY + " z=" + rescaleZ + 
            " interpolation=Bilinear average process create title=rescaled");
        close("processed");
        
        // Build output filename
        originalName = substring(list[i], 0, lengthOf(list[i]) - 4); // Remove ".ims"
        savePath = folder + "processed_" + originalName + ".tif";
        
        // Save
        saveAs("Tiff", savePath);
        close("rescaled");
        
        print("Saved: " + savePath);
    }
}
