{*******************************************************************************
  VoronoiEngine v0.1
********************************************************************************
  A high-performance, threaded VCL Raylib component for 3D mesh fracturing.
  Utilizing Raylib for off-screen/native rendering embedded in VCL.

  Key Features:
  - Threaded Architecture: Separates Raylib Game Loop from the UI Thread.
  - Non-Blocking UI: Main thread remains responsive even at high load.
  - Precise Frame Pacing: QPC-based absolute frame deadlines with a hybrid
    Sleep/SpinWait strategy.
  - RealFPS Monitoring: Counts the actual frames produced by the Raylib
    render loop per second.
  - Custom Physics: Basic kinematics applied to Voronoi fragments.

   Author: Lara Miriam Tamy Reschke / LamitaOne

*******************************************************************************}

unit uVoronoiEngine;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math, System.SyncObjs,
  Winapi.Windows, Winapi.MMSystem, Vcl.Controls, Raylib, rlgl, RayMath,
  Yutani.VoronoiFracture;

const
  SPIN_THRESHOLD_NS = 2000000; // 2 ms threshold for spin-waiting

type
  // High-resolution timer using QueryPerformanceCounter (QPC)
  THighResTimer = record
    Frequency: Int64;
    procedure Init;
    function GetTicks: Int64; inline;
    procedure HybridWaitUntil(const ATargetTicks, ASpinNanoseconds: Int64);
  end;

  TVoronoiEngine = class(TThread)
  private
    FParentHandle: HWND;
    FRaylibWnd: HWND;
    FTargetFPS: Integer;
    FRealFPS: Integer;
    FActive: Boolean;
    FPhysicsActive: Integer; // Used as an atomic flag (0 = inactive, 1 = active)
    FFragments: TFragmentArray;
    FCamera: TCamera3D;
    FWidth, FHeight: Integer;

    procedure DoExplode;
    procedure UpdatePhysics(const DeltaTime: Double);
    procedure RenderScene;
    procedure SetActive(const Value: Boolean);
  protected
    procedure Execute; override;
  public
    constructor Create(AParentHandle: HWND);
    destructor Destroy; override;

    procedure StartEngine;
    procedure StopEngine;
    procedure Explode;
    procedure SetFPS(const FPS: Integer);
    procedure SetDimensions(const W, H: Integer);

    property RealFPS: Integer read FRealFPS;
    property TargetFPS: Integer read FTargetFPS;
    property Active: Boolean read FActive write SetActive;
  end;

implementation

function Vec3(X, Y, Z: Single): TVec3;
begin
  Result.X := X;
  Result.Y := Y;
  Result.Z := Z;
end;

{ THighResTimer }

procedure THighResTimer.Init;
begin
  if not QueryPerformanceFrequency(Frequency) then
    Frequency := 0;
end;

function THighResTimer.GetTicks: Int64;
begin
  QueryPerformanceCounter(Result);
end;

// Hybrid sleep strategy: Sleep(1) for long waits, SpinWait for short waits
// This prevents thread context switching overhead while maintaining high precision.
procedure THighResTimer.HybridWaitUntil(const ATargetTicks, ASpinNanoseconds: Int64);
var
  SpinTicks, Remaining: Int64;
begin
  if Frequency = 0 then
    Exit;
  SpinTicks := (ASpinNanoseconds * Frequency) div 1000000000;

  Remaining := ATargetTicks - GetTicks;
  while Remaining > SpinTicks do
  begin
    Sleep(1);
    Remaining := ATargetTicks - GetTicks;
  end;

  // Spin-wait the remaining time for exact frame pacing
  while GetTicks < ATargetTicks do
    ;
end;

{ TVoronoiEngine }

constructor TVoronoiEngine.Create(AParentHandle: HWND);
begin
  inherited Create(True); // Create suspended
  FreeOnTerminate := False;
  FParentHandle := AParentHandle;
  FTargetFPS := 60;
  FActive := False;
  FPhysicsActive := 0;
  FWidth := 800;
  FHeight := 600;

  // Default camera setup
  FCamera.position := Vector3Create(10.0, 10.0, 10.0);
  FCamera.target := Vector3Create(0, 1, 0);
  FCamera.up := Vector3Create(0, 1, 0);
  FCamera.fovy := 45.0;
  FCamera.projection := CAMERA_PERSPECTIVE;
end;

destructor TVoronoiEngine.Destroy;
begin
  StopEngine;
  SetLength(FFragments, 0);
  inherited;
end;

procedure TVoronoiEngine.SetDimensions(const W, H: Integer);
begin
  FWidth := W;
  FHeight := H;
  // Resize the embedded Raylib window
  if FRaylibWnd <> 0 then
    SetWindowPos(FRaylibWnd, 0, 0, 0, FWidth, FHeight, SWP_NOZORDER or SWP_NOACTIVATE);
end;

procedure TVoronoiEngine.SetActive(const Value: Boolean);
begin
  if FActive <> Value then
  begin
    FActive := Value;
    if FActive then
    begin
      if Suspended then
        Start;
    end;
  end;
end;

procedure TVoronoiEngine.StartEngine;
begin
  Active := True;
end;

procedure TVoronoiEngine.StopEngine;
begin
  Active := False;
end;

procedure TVoronoiEngine.Explode;
begin
  DoExplode;
end;

procedure TVoronoiEngine.SetFPS(const FPS: Integer);
begin
  if FTargetFPS <> FPS then
    FTargetFPS := FPS;
end;

procedure TVoronoiEngine.DoExplode;
var
  BaseMesh: TPolyMesh;
  Seeds: array of TVec3;
  I: Integer;
  Dir, SeedPos: TVec3;
begin
  // Atomically check if physics are already running, if so, exit
  if TInterlocked.Exchange(FPhysicsActive, 1) = 1 then
    Exit;

  // 1. Define base mesh (A simple 2x2x2 Cube)
  SetLength(BaseMesh, 6);
  SetLength(BaseMesh[0], 4);
  BaseMesh[0][0] := Vec3(-1, 0, 1);
  BaseMesh[0][1] := Vec3(1, 0, 1);
  BaseMesh[0][2] := Vec3(1, 2, 1);
  BaseMesh[0][3] := Vec3(-1, 2, 1);
  SetLength(BaseMesh[1], 4);
  BaseMesh[1][0] := Vec3(1, 0, -1);
  BaseMesh[1][1] := Vec3(-1, 0, -1);
  BaseMesh[1][2] := Vec3(-1, 2, -1);
  BaseMesh[1][3] := Vec3(1, 2, -1);
  SetLength(BaseMesh[2], 4);
  BaseMesh[2][0] := Vec3(-1, 0, -1);
  BaseMesh[2][1] := Vec3(-1, 0, 1);
  BaseMesh[2][2] := Vec3(-1, 2, 1);
  BaseMesh[2][3] := Vec3(-1, 2, -1);
  SetLength(BaseMesh[3], 4);
  BaseMesh[3][0] := Vec3(1, 0, 1);
  BaseMesh[3][1] := Vec3(1, 0, -1);
  BaseMesh[3][2] := Vec3(1, 2, -1);
  BaseMesh[3][3] := Vec3(1, 2, 1);
  SetLength(BaseMesh[4], 4);
  BaseMesh[4][0] := Vec3(-1, 2, 1);
  BaseMesh[4][1] := Vec3(1, 2, 1);
  BaseMesh[4][2] := Vec3(1, 2, -1);
  BaseMesh[4][3] := Vec3(-1, 2, -1);
  SetLength(BaseMesh[5], 4);
  BaseMesh[5][0] := Vec3(-1, 0, -1);
  BaseMesh[5][1] := Vec3(1, 0, -1);
  BaseMesh[5][2] := Vec3(1, 0, 1);
  BaseMesh[5][3] := Vec3(-1, 0, 1);

  // 2. Generate random Voronoi seeds inside the cube
  SetLength(Seeds, 15);
  for I := 0 to High(Seeds) do
    Seeds[I] := Vec3((Random * 2.0) - 1.0, (Random * 2.0), (Random * 2.0) - 1.0);

  // 3. Fracture the mesh using the Voronoi algorithm
  FFragments := FractureMesh(BaseMesh, Seeds);

  // 4. Assign initial kinematic properties to fragments
  for I := 0 to High(FFragments) do
  begin
    FFragments[I].RotationAxis := Vec3(Random * 2 - 1, Random * 2 - 1, Random * 2 - 1).Normalize;

    if (Length(FFragments[I].Mesh) > 0) and (Length(FFragments[I].Mesh[0]) > 0) then
      SeedPos := FFragments[I].Mesh[0][0]
    else
      SeedPos := Vec3(0, 0, 0);

    Dir := SeedPos;
    if Dir.LengthSq < 0.01 then
      Dir := Vec3(Random * 2 - 1, Random * 2 - 1, Random * 2 - 1);

    Dir := Dir.Normalize;
    Dir.Y := Dir.Y + 1.5; // Bias direction upwards

    FFragments[I].Velocity := Dir * (4 + Random * 4);
    FFragments[I].AngularVelocity := (Random * 4) - 2;
  end;
end;

procedure TVoronoiEngine.UpdatePhysics(const DeltaTime: Double);
var
  I: Integer;
  IsActive: Boolean;
begin
  // Atomic read to check if physics should be simulated
  IsActive := TInterlocked.CompareExchange(FPhysicsActive, 0, 0) > 0;
  if not IsActive then
    Exit;

  // Simple Euler integration for fragment kinematics
  for I := 0 to High(FFragments) do
  begin
    // Apply gravity
    FFragments[I].Velocity.Y := FFragments[I].Velocity.Y - (9.81 * DeltaTime);
    FFragments[I].Position := FFragments[I].Position + (FFragments[I].Velocity * DeltaTime);
    FFragments[I].Angle := FFragments[I].Angle + (FFragments[I].AngularVelocity * DeltaTime);

    // Ground collision response
    if FFragments[I].Position.Y < 0 then
    begin
      FFragments[I].Position.Y := 0;
      FFragments[I].Velocity.Y := -FFragments[I].Velocity.Y * 0.4; // Bounce
      FFragments[I].Velocity.X := FFragments[I].Velocity.X * 0.8; // Friction
      FFragments[I].Velocity.Z := FFragments[I].Velocity.Z * 0.8;
      FFragments[I].AngularVelocity := FFragments[I].AngularVelocity * 0.5;
    end;
  end;
end;

procedure TVoronoiEngine.RenderScene;
var
  I, J, K: Integer;
  IsActive: Boolean;
begin
  IsActive := TInterlocked.CompareExchange(FPhysicsActive, 0, 0) > 0;

  BeginDrawing();

  // Enable depth testing for 3D, disable backface culling for fragmented meshes
  rlEnableDepthTest();
  rlDisableBackfaceCulling();

  ClearBackground(BLACK);

  BeginMode3D(FCamera);
  DrawGrid(20, 1.0);

  if not IsActive then
  begin
      // Draw intact base cube
    rlPushMatrix();
    rlTranslatef(0, 0, 0);
    DrawCube(Vector3Create(0, 1, 0), 2.0, 2.0, 2.0, Fade(RED, 0.5));
    DrawCubeWires(Vector3Create(0, 1, 0), 2.0, 2.0, 2.0, MAROON);
    rlPopMatrix();
  end
  else
  begin
      // Draw Voronoi fragments manually via low-level rlgl
    rlBegin(RL_TRIANGLES);
    for I := 0 to High(FFragments) do
    begin
      rlPushMatrix();
      rlTranslatef(FFragments[I].Position.X, FFragments[I].Position.Y, FFragments[I].Position.Z);
      rlRotatef(FFragments[I].Angle * 57.2958, FFragments[I].RotationAxis.X, FFragments[I].RotationAxis.Y, FFragments[I].RotationAxis.Z);

          // Simple colorization based on fragment index
      rlColor4ub((I * 50) mod 255, (I * 100) mod 255, (I * 150) mod 255, 255);

          // Triangulate and draw the fragment mesh (Convex Fan Triangulation)
      for J := 0 to High(FFragments[I].Mesh) do
      begin
        if Length(FFragments[I].Mesh[J]) >= 3 then
        begin
          for K := 1 to Length(FFragments[I].Mesh[J]) - 2 do
          begin
            rlVertex3f(FFragments[I].Mesh[J][0].X, FFragments[I].Mesh[J][0].Y, FFragments[I].Mesh[J][0].Z);
            rlVertex3f(FFragments[I].Mesh[J][K].X, FFragments[I].Mesh[J][K].Y, FFragments[I].Mesh[J][K].Z);
            rlVertex3f(FFragments[I].Mesh[J][K + 1].X, FFragments[I].Mesh[J][K + 1].Y, FFragments[I].Mesh[J][K + 1].Z);
          end;
        end;
      end;
      rlPopMatrix();
    end;
    rlEnd();
  end;

  EndMode3D();

  // Restore default states for 2D UI text rendering
  rlEnableBackfaceCulling();
  rlDisableDepthTest();

  DrawText('Click [Explode!] to destroy the cube', 10, 10, 20, RAYWHITE);
  DrawText(PAnsiChar(AnsiString('Fragments: ' + IntToStr(Length(FFragments)))), 10, 40, 20, LIGHTGRAY);

  EndDrawing();

  // Force VCL to update the parent control where Raylib is embedded
  if FRaylibWnd <> 0 then
    RedrawWindow(FRaylibWnd, nil, 0, RDW_INVALIDATE or RDW_UPDATENOW);
end;

procedure TVoronoiEngine.Execute;
var
  Timer: THighResTimer;
  Freq, FrameTicks: Int64;
  NextFrame, NowTicks, LastFrameTicks: Int64;
  DeltaSec: Double;
  FrameCount: Integer;
  LastFpsTime: Int64;
  WindowName: AnsiString;
begin
  // Increase Windows timer resolution for Sleep(1) accuracy
  {$IFDEF MSWINDOWS}
  timeBeginPeriod(1);
  {$ENDIF}
  try
    SetConfigFlags(FLAG_MSAA_4X_HINT);

    // Generate a unique window name to prevent handle collisions
    WindowName := AnsiString('VoronoiEngine_' + IntToStr(IntPtr(Self)));
    InitWindow(FWidth, FHeight, PAnsiChar(WindowName));

    // Retrieve the newly created Raylib window handle and embed it into VCL
    FRaylibWnd := FindWindowA(nil, PAnsiChar(WindowName));
    if (FRaylibWnd <> 0) and (FParentHandle <> 0) then
    begin
      Winapi.Windows.SetParent(FRaylibWnd, FParentHandle);
      SetWindowLong(FRaylibWnd, GWL_STYLE, WS_CHILD or WS_VISIBLE);
      SetWindowPos(FRaylibWnd, 0, 0, 0, FWidth, FHeight, SWP_NOZORDER or SWP_NOACTIVATE);
    end;

    // Initialize frame pacing timers
    Timer.Init;
    Freq := Timer.Frequency;
    if Freq <= 0 then
      Freq := 10000000;

    NowTicks := Timer.GetTicks;
    LastFrameTicks := NowTicks;
    NextFrame := NowTicks;
    LastFpsTime := NowTicks;
    FrameCount := 0;

    // Main Raylib Loop
    while not Terminated do
    begin
      if WindowShouldClose() then
        Break;

      NowTicks := Timer.GetTicks;
      DeltaSec := (NowTicks - LastFrameTicks) / Freq;
      LastFrameTicks := NowTicks;

      // Clamp delta time to avoid physics tunnelling on lag spikes
      if (DeltaSec <= 0) or (DeltaSec > 0.25) then
        DeltaSec := 1 / 60;

      if FActive then
        UpdatePhysics(DeltaSec);

      RenderScene;

      // Real FPS calculation
      Inc(FrameCount);
      if (NowTicks - LastFpsTime) >= Freq then
      begin
        FRealFPS := Round(FrameCount * Freq / (NowTicks - LastFpsTime));
        FrameCount := 0;
        LastFpsTime := NowTicks;
      end;

      // Calculate exact deadline for the next frame
      if FTargetFPS > 0 then
        FrameTicks := Round(Freq / FTargetFPS)
      else
        FrameTicks := Freq div 60;

      NextFrame := NextFrame + FrameTicks;

      // If we are falling behind, reset NextFrame to current time to prevent fast-catching
      NowTicks := Timer.GetTicks;
      if (NowTicks - NextFrame) > Freq then
        NextFrame := NowTicks;

      // Wait precisely until the next frame deadline
      Timer.HybridWaitUntil(NextFrame, SPIN_THRESHOLD_NS);
    end;

  finally
    if FRaylibWnd <> 0 then
      CloseWindow();

    {$IFDEF MSWINDOWS}
    timeEndPeriod(1);
    {$ENDIF}
  end;
end;

end.

