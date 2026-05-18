# Infinite-Mandelbrot

## Description

This is a project made with Godot to explore the Mandelbrot Set using shaders and arbitrary-precision arithmetic to achieve infinite zoom.

## Idea

We start with the view of the box $[-2,\ 2] \times [-2,\ 2]$ in the Cartesian plane, with the Mandelbrot Set displayed inside it. When the user clicks on any point inside this box, the selected point becomes the new center and a zoom of 2x is applied. The new box now has sides of length 2 (half of the initial length of 4). The corresponding view of the Mandelbrot Set is rendered again. This process can be repeated an arbitrary number of times, allowing the user to zoom-in indefinitely.

<p align="center">
    <img width="700" src="https://github.com/user-attachments/assets/f3efdf18-89b9-4aeb-a8b1-7d010a9c7440" />
</p>

The vertices of the box and all its inners points are stored through the following system: given any real number

$$\pm\ a_0\ a_1\ \ldots a_m . a_{m+1}\ a_{m+2}\ \ldots a_n$$

the system stores this number as the array

$$[d,\ \pm\ a_0,\ a_1,\ \ldots, a_m,\ a_{m+1},\ a_{m+2},\ \ldots, a_n]$$

where $d$ is the position of the decimal point.

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
