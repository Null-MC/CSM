# Minecraft single-pass CSM Demo

A very minimal proof-of-concept demo for using Cascaded Shadow Mapping in Minecraft. This is meant to serve as a learning resource or template for other works, not as a final product itself. 


## Shadow Types
- **None**  
  No shadows at all. Just a visual/performance benchmark comparison.

- **Basic**  
  Uses the Optifine defaults for shadow mapping, with no additional improvements. It's expected to look _really_ bad...

- **Distorted**  
  Uses the Optifine defaults for shadow mapping, but also applies distortion to the projection to improve detail of nearby shadows. This significantly improves quality, but also causes visible displacement of long shadows.

- **Cascading**  
  Splits the shadow map into 4 cascades with varying levels of detail. This greatly improves shadow quality in the same way as distorted shadow maps, but does not cause any visual distortion since it is completely orthographic. This does however introduce artifacts when objects transition between different cascade levels.


## Filter Types
- **None**  
  No filtering of shadow map, just a simple binary result.

- **PCF**  
  Uses a fixed-size kernel to perform percent-closer-filtering of the shadowmap. This provides a fixed softening factor for shadows, but also introduces visual artifects as sample occlusion will increase with light angle.

- **PCF + PCSS**  
  Extends PCF filtering with percent-closer-soft-shadows. This technique uses an additional pre-blocker-check to adjust the radius of the PCF filtering, removing the artifacts caused by PCF alone.


# Implementation Details
Since there is no access to the CPU side for splitting the frustum, culling, and shadow buffers - this technique instead uses a single shadow buffer split into 4 quadrants. Each equally sized quadrant is used as a cascade, meaning this approach uses a fixed count of 4 cascades. Since this is all handled in a single pass, geometry is shifted into each quadrant based on distance. Because there is no overlap between cascades, it is required to sample all cascades to find occlusions.

:information: For best performance, use Iris 1.6 or later.


### Special thanks to:
- Balint: Providing a correct projection matrix function, waving leaves
- BuilderBoy: Providing player detection
- Lith: Providing entity detection
- Zombye: Providing a correct block-snapping function
