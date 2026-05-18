# Infinite-Mandelbrot

## Description

This is a project made with Godot to explore the Mandelbrot Set using shaders and arbitrary-precision arithmetic to achieve infinite zoom.

## Idea

We start with the view of the box $[-2, 2] \times [-2, 2]$ in the Cartesian plane, with the Mandelbrot Set displayed inside it. When the user clicks on any point inside this box, the selected point becomes the new center and a zoom of 2x is applied. The new box now has sides of length 2 (half of the initial length of 4). The corresponding view of the Mandelbrot Set is rendered again. This process can be repeated an arbitrary number of times, allowing the user to zoom-in indefinitely.



## Next Steps
        Converter float to int array ✔️
        Array arithmetic ✔️
        Zoom-in system, box vertex calculation (numeric only)
        Zoom-out system, box vertex calculation (numeric only)
        System for increasing/decreasing the precision of int arrays

## Release history

### v0.0.1
    The project officially begins

### v0.1.0
    ### New ###
    - Interactive zoom-in
    - Better statistics tracking

    ### Improvements ###
    - Class file arbitrary-precision arithmetic

    ### Fixes ###
    - README file missing
