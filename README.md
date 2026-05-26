# Infinite-Mandelbrot

## Description

This is a project made with Godot to explore the Mandelbrot Set using shaders and arbitrary-precision arithmetic to achieve infinite zoom.

## Idea

We start with the view of the box $[-2,\ 2] \times [-2,\ 2]$ in the Cartesian plane, with the Mandelbrot Set displayed inside it. When the user clicks on any point inside this box, the selected point becomes the new center and a zoom of 2x is applied. The new box now has sides of length 2 (half of the initial length of 4). The corresponding view of the Mandelbrot Set is rendered again. This process can be repeated an arbitrary number of times, allowing the user to zoom-in indefinitely. Each point within the box is obtained by converting the UV coordinate into the respective horizontal and vertical coordinate arrays.

<p align="center">
    <img width="700" src="https://github.com/user-attachments/assets/f3efdf18-89b9-4aeb-a8b1-7d010a9c7440" />
</p>

The vertices of the box and all its inners points are stored through the following system: given any real number

$$\pm\ a_0\ a_1\ \ldots a_m . a_{m+1}\ a_{m+2}\ \ldots a_n$$

the system stores this number as the array

$$[d,\ \pm\ a_0,\ a_1,\ \ldots, a_m,\ a_{m+1},\ a_{m+2},\ \ldots, a_n]$$

where $d$ is the position of the decimal point. The four vertices are passed to the shader as uniform. Then the shader uses internal arithmetic routines to perform the digit-by-digit calculations, with the array representation. There is no actual zooming happening, the box's location is always determined by the four vertices.

Let $A, B, C, D$ be the four vertices of the box and $E$ be its center. Denote $A = (A_x, A_y)$, the notation for the other points is similar. By definition, the box is a square. 

<p align="center">
    <img width="300" src="https://github.com/user-attachments/assets/66f16250-7a3f-4e4f-a3ab-ddf339d52aef" />
</p>

Let $\ell$ be the length of its sides, then it follows that 

$$A = \left( E_x - \frac{\ell}{2}, E_y + \frac{\ell}{2} \right)$$
$$B = \left( E_x + \frac{\ell}{2}, E_y + \frac{\ell}{2} \right)$$
$$C = \left( E_x - \frac{\ell}{2}, E_y - \frac{\ell}{2} \right)$$
$$D = \left( E_x + \frac{\ell}{2}, E_y - \frac{\ell}{2} \right)$$

On the side of the shader, the coordinate system is a bit different, with the default as shown below.

<p align="center">
    <img width="330" src="https://github.com/user-attachments/assets/c0d34bc5-ab7a-4fb0-82d8-0101af2a51f3" />
</p>

The following maps are applied in sequence to transform the default UV box into the desired box:

$$(u,\ v) \overset{(u,\ 1-v)}{\mapsto} \overset{(u - 0.5,\ v - 0.5)}{\mapsto} \overset{(u \cdot \ell,\ v \cdot \ell)}{\mapsto} \overset{(u + E_x,\ v + E_y)}{\mapsto}$$

## Release history

### v0.0.1
    The project officially begins

### v0.1.0
    ### New ###
    - Interactive zoom-in

    ### Improvements ###
    - Class file arbitrary-precision arithmetic

    ### Fixes ###
    - README file missing

### v0.2.0
    ### New ###
    - Array arithmetic with shaders working
	
### v0.3.0
	### New ###
	- Rendering of the fractal with shaders
	
### v0.3.1
	### Improvements ###
	- More precision in general
	
### v0.4.0
	### New ###
	- UI
	- Three levels of precision to change during the execution (with three shader files)
	
	### Fixes ###
	- During the zoom, the box size and its half were being considered the same, this is fixed now
	
### v0.4.1
	### New ###
	- Help/About button

	### Improvements ###
	- Making the figure of "where am I" more correct
	- Changing Label to RichTextLabel so the user can copy the numbers
	- The default tile size has been reduced from 100 to 50 to prevent crashes due to slow GPU computation
	
	### Fixes ###
	- Removing unused files
	- Zoom Label text updated

### v0.5.0
	### New ###
	- Main resolution set to 1024x1024 instead of 500x500
	- Mouse cursor stylized
	- Game icon defined
	- "Go to" functionality done
	- Restart button
	- Quit button
	- 1x zoom to move around
	
	### Improvements ###
	- The default tile size has been changed from 50 to 64
	- Max iter GUI is an option select box insted of slider now
	
### v1.0.0
	### New ###
	- Stable version
### v1.0.1
	### Fixes ###
	- Fixing title blocking mouse interaction with the game
	- Maximized screen by default
	
### v1.0.2 ###
	### Improvements ###
	- Better palette
	
### v1.0.3 ###
	### Improvements ###
	- Dynamic tile sizes
	
	### Fixes ###
	- Fixed bug in "Go to", it was using an old function name