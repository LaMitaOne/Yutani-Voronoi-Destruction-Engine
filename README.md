# Yutani-Voronoi-Destruction-Engine v0.1    
A custom, high-performance 3D mesh fracturing and destruction engine written in pure Delphi.    
        
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/Yutani-Voronoi-Destruction-Engine)     
       
<img width="883" height="688" alt="Unbenannt" src="https://github.com/user-attachments/assets/2107d9d0-f9a2-4fb0-930d-51f65d1fdb91" />
     
https://github.com/user-attachments/assets/abd39915-d653-4060-a399-c229ba6504f7      
         
Instead of relying on heavy external physics engines, this project implements 3D Voronoi cell generation, Sutherland-Hodgman mesh clipping, and basic kinematic physics from scratch. It is designed to dynamically shatter convex meshes into realistic fragments in real-time.   
     
🚀 Key Features     
    
     Custom Voronoi Math: A from-scratch implementation of 3D Voronoi cell generation. It slices a base convex mesh using bisection planes between random seeds.
     Sutherland-Hodgman Clipping: Precisely slices polygons and automatically generates new "cap" polygons where intersections occur, ensuring fragments remain solid and closed. 
     Robust Normals & Sorting: Uses Newell's method to calculate accurate surface normals for newly generated caps, with counter-clockwise (CCW) sorting to ensure correct triangulation.
     Custom Physics Simulation: Implements basic Euler integration for fragment kinematics (gravity, velocity, angular rotation) including ground collision response, bounce, and friction.
     Real-time Generation: The mesh is fractured and brought into motion dynamically at runtime without any pre-computation.
     
📦 The Sample Project     
     
To demonstrate the engine in action, a demo application is included.     
     
    Start: Clicking Start Engine initializes the 3D scene.
    The Scene: A standard 2x2x2 cube is rendered in 3D space.
    Explode!: Clicking Explode! triggers the Voronoi algorithm. 15 random seeds are generated inside the cube. The engine calculates the bisection planes, slices the cube into fragments, assigns random outward velocities, and drops them into the custom physics simulation.
    Performance Tuning: A TrackBar at the top allows you to dynamically change the Target FPS of the render thread (from 1 up to 5000 FPS) to test the engine's limits.
         
📁 Repository Structure    
    
     Yutani.VoronoiFracture.pas - Pure math/logic unit for vector operations, mesh clipping, and Voronoi cell generation.
     uVoronoiEngine.pas - The engine wrapper handling the physics integration and threaded rendering.
     Unit1.pas - The VCL demo form.
    
🛠️ Requirements    
    
     Delphi: Tested with Delphi 12 (should work on Delphi 10.4 and newer due to record operator syntax).
     Raylib Pascal Bindings: Required to compile the included sample application (Raylib, rlgl, RayMath).
     Raylib DLL: The compiled raylib.dll must be in the executable directory.
     
Author: Lara Miriam Tamy Reschke / LamitaOne   
