# Minecraft CSM Sample
A very minimal proof-of-concept/template for using Cascaded Shadow Mapping in Minecraft. Since there is no access to the CPU side for splitting the frustum, culling, and shadow buffers - this technique instead uses a single shadow buffer split into 4 quadrants. Each equally sized quadrant is used as a cascade, meaning this approach uses a fixed count of 4 cascades. Since this is all handled in a single pass, geometry is shifted into each quadrant based on distance. Because there is no overlap between cascades, it is required to sample all cascades to find occlusions.

Currently this requires Optifine, as vanilla Fabulous shaders do not provide a shadow pass, and Iris does not support the required `at_midBlock` attribute.

### Special thanks to:
- Balint: Providing a correct projection matrix function, waving leaves
- BuilderBoy: Providing player detection
- Zombye: Providing a correct block-snapping function
- Lith: Providing entity detection


## Shadow Types
#### None
No shadows at all.

#### Basic
Uses the Optifine defaults for shadow mapping, with no additional improvements.

#### Distorted
Uses the Optifine defaults for shadow mapping, but also applies distortion to the projection to improve detail of nearby shadows.

#### CSM
Splits the shadow map into 4 cascades with varying levels of detail.
