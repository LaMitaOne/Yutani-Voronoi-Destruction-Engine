{*******************************************************************************
  Voronoi Demo Form v0.1
********************************************************************************
  VCL Wrapper demonstrating the TVoronoiEngine.
  Dynamically constructs UI controls and embeds the threaded Raylib renderer.

   Author: Lara Miriam Tamy Reschke / LamitaOne

*******************************************************************************}

unit Unit1;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, uVoronoiEngine;

type
  TForm1 = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
  private
    FEngine: TVoronoiEngine;
    btnStart: TButton;
    btnExplode: TButton;
    pnlUI: TPanel;
    pnlRender: TPanel;
    tbFPS: TTrackBar;
    lblFPS: TLabel;
    FPSTimer: TTimer;

    procedure OnStartClick(Sender: TObject);
    procedure OnExplodeClick(Sender: TObject);
    procedure OnFPSTracking(Sender: TObject);
    procedure OnFPSTimer(Sender: TObject);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
  Caption := 'Yutani Voronoi Destruction Demo';
  Self.DoubleBuffered := True;
  Width := 900;
  Height := 700;

  // 1. Render Panel: Hosts the Raylib child window
  pnlRender := TPanel.Create(Self);
  pnlRender.Parent := Self;
  pnlRender.Align := alClient;
  pnlRender.BevelOuter := bvNone;
  pnlRender.Caption := '';

  // 2. UI Panel: Contains buttons and trackbar
  pnlUI := TPanel.Create(Self);
  pnlUI.Parent := Self;
  pnlUI.Align := alTop;
  pnlUI.Height := 65;
  pnlUI.BevelOuter := bvNone;
  pnlUI.Caption := '';
  pnlUI.DoubleBuffered := True;
  pnlUI.BringToFront;

  // 3. Start Button
  btnStart := TButton.Create(Self);
  btnStart.Parent := pnlUI;
  btnStart.Caption := 'Start Engine';
  btnStart.Width := 120;
  btnStart.Left := 20;
  btnStart.Top := 10;
  btnStart.OnClick := OnStartClick;

  // 4. Explode Button
  btnExplode := TButton.Create(Self);
  btnExplode.Parent := pnlUI;
  btnExplode.Caption := 'Explode!';
  btnExplode.Width := 120;
  btnExplode.Left := 150;
  btnExplode.Top := 10;
  btnExplode.OnClick := OnExplodeClick;

  // 5. FPS Label
  lblFPS := TLabel.Create(Self);
  lblFPS.Parent := pnlUI;
  lblFPS.Caption := 'Target: 60 | Real: 0 FPS';
  lblFPS.Left := 300;
  lblFPS.Top := 15;
  lblFPS.Width := 200;
  lblFPS.Font.Size := 10;

  // 6. FPS TrackBar
  tbFPS := TTrackBar.Create(Self);
  tbFPS.Parent := pnlUI;
  tbFPS.Min := 1;
  tbFPS.Max := 5000;
  tbFPS.Position := 60;
  tbFPS.Width := 250;
  tbFPS.Left := 500;
  tbFPS.Top := 10;
  tbFPS.OnChange := OnFPSTracking;

  // 7. UI Update Timer
  FPSTimer := TTimer.Create(Self);
  FPSTimer.Interval := 500;
  FPSTimer.OnTimer := OnFPSTimer;
  FPSTimer.Enabled := True;

  // Instantiate engine and bind to Render Panel handle
  FEngine := TVoronoiEngine.Create(pnlRender.Handle);
  FEngine.SetDimensions(pnlRender.Width, pnlRender.Height);
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  if Assigned(FEngine) and Assigned(pnlRender) then
    FEngine.SetDimensions(pnlRender.Width, pnlRender.Height);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  if Assigned(FEngine) then
  begin
    FEngine.StopEngine;
    FEngine.Terminate;
    FEngine.WaitFor;
    FEngine.Free;
  end;
end;

procedure TForm1.OnStartClick(Sender: TObject);
begin
  if Assigned(FEngine) then
    FEngine.StartEngine;
end;

procedure TForm1.OnExplodeClick(Sender: TObject);
begin
  if Assigned(FEngine) then
    FEngine.Explode;
end;

procedure TForm1.OnFPSTracking(Sender: TObject);
begin
  if Assigned(FEngine) and Assigned(tbFPS) then
  begin
    FEngine.SetFPS(Round(tbFPS.Position));
  end;
end;

procedure TForm1.OnFPSTimer(Sender: TObject);
begin
  if Assigned(FEngine) and Assigned(lblFPS) then
  begin
    lblFPS.Caption := Format('Target: %d | Real: %d FPS', [FEngine.TargetFPS, FEngine.RealFPS]);
  end;
end;

end.

