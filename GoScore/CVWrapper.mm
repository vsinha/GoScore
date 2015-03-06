//
//  CVWrapper.m
//  CVOpenTemplate
//
//  Created by Washe on 02/01/2013.
//  Copyright (c) 2013 foundry. All rights reserved.
//

#import "CVWrapper.h"
#import "UIImage+OpenCV.h"


@implementation CVWrapper

+ (UIImage*) processImageWithOpenCV: (UIImage*) inputImage
{
    // convert our input image to the correct format
    cv::Mat inputMat = [inputImage CVMat3];
    cv::Mat inputGreyMat;           // to store greyscale image
    cv::Mat outputMat;
    cv::vector<cv::Vec3f> circles;  // to store identified circles

    // convert image to grey
    cv::cvtColor(inputMat, inputGreyMat, CV_BGR2GRAY);
    
    
    /* 0: Binary
     1: Binary Inverted
     2: Threshold Truncated
     3: Threshold to Zero
     4: Threshold to Zero Inverted
     */
    //cv::threshold( inputGreyMat, inputGreyMat, 200, 255, 0);
    //cv::threshold( inputGreyMat, inputGreyMat, 128, 255, 4);
    
    //reduce noise so we avoid false circle detection
    cv::GaussianBlur(inputGreyMat, inputGreyMat, cv::Size(3, 3), 2, 2 );
    
//    {
//    double maxValue = 255; // Non-zero value assigned to the pixels for which the condition is satisfied.
//    int adaptiveMethod = CV_ADAPTIVE_THRESH_GAUSSIAN_C; // CV_ADAPTIVE_THRESH_MEAN_C or CV_ADAPTIVE_THRESH_GAUSSIAN_C
//    int thresholdType = CV_THRESH_BINARY; // either CV_THRESH_BINARY or CV_THRESH_BINARY_INV
//    int blockSize = 13; // Size of a pixel neighborhood that is used to calculate a threshold value for the pixel: 3, 5, 7, and so on.
//    double constantSubtracted = 2; // Constant subtracted from the mean or weighted mean
//    cv::adaptiveThreshold(inputGreyMat, inputGreyMat, maxValue, adaptiveMethod, thresholdType, blockSize, constantSubtracted);
//    }
    
//    cv::cvtColor(inputGreyMat, outputMat, CV_GRAY2BGR);
    outputMat = inputMat;

    {
    int method = CV_HOUGH_GRADIENT; // only method implemented in opencv 2.4
    double dp = 1;       // Inverse ratio of the accumulator resolution to the image resolution (dp = 1 -> both are the same resolution)
    double minDist = 15; // min distance between centers of the detected circles (too small = multiple neighbor circles, too large = missed circles)
    double cannyThreshold = 100; // higher threshold passed to the internal Canny() edge detector
    double accumThreshold = 21;  // accumulator threshold for circle centers at the detection stage (smaller = more false circles)
    int minRadius = 5;   // min circle radius
    int maxRadius = 30;  // max circle radius
    cv::HoughCircles(inputGreyMat, circles, method, dp, minDist, cannyThreshold, accumThreshold, minRadius, maxRadius);
    }
    
    
    // iterate over identified circles
    for (size_t i = 0; i < circles.size(); i++) {
        
        cv::Point center(cvRound(circles[i][0]), cvRound(circles[i][1]));
        int radius = cvRound(circles[i][2]);
        
        //get region of interest for each circle and use it to estimate what color circle we have
        // TODO make sure range is valid...
        //cv::Mat roi = inputMat(cv::Range((int)circles[i][1] - 2, (int)circles[i][1] + 2),
        //                       cv::Range((int)circles[i][0] - 2, (int)circles[i][0] + 2));
        
        //cv::Mat1b mask(roi.rows, roi.cols);
        //cv::Scalar mean = cv::mean(roi, mask);
        //float meanOfMeans = (mean[0] + mean[1] + mean[2]) / 3;
        
        //std::cout << "mean color value: " << meanOfMeans << "\n";
        
        std::cout << "circle radius: " << radius << " center: (" << center.x << ", " << center.y << ")" << "\n";
        
        // draw the circle centers in different colors depending on the color
        //if (meanOfMeans >= 128) { // conclude we have a white circle
            circle(outputMat, center, 3, cv::Scalar(255, 0, 0), -1, 5, 0);

        //} else { // black circle
          //  circle(inputGreyMat, center, 3, cv::Scalar(255, 255, 255), -1, 5, 0);
        //}
        
        // draw circle outline
        circle(outputMat, center, radius, cv::Scalar(0, 0, 255), 1, 2, 0);
    }
    
    // convert mat to uiimage
    UIImage *circleDetectedInput = [UIImage imageWithCVMat:outputMat];
    return circleDetectedInput;
}

@end
