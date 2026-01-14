unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, NuiApi, NuiSensor, EventDispatcherThread, StdCtrls, ExtCtrls, Math,
  System.Generics.Collections, Async32, System.IniFiles,
  Vcl.ComCtrls, cxGraphics, cxControls, cxLookAndFeels, cxLookAndFeelPainters,
  System.Math.Vectors,
  cxContainer, cxEdit, cxLabel, Vcl.Menus, cxButtons;

type
  TKalmanFilter = record
    Q: Single;  // шум процесса
    R: Single;  // шум измерения
    P: Single;  // ковариационная ошибка
    X: Single;  // оценка
    K: Single;  // коэффициент Кальмана
  end;

 TKalmanFilter2D = record
    X: TKalmanFilter;
    Y: TKalmanFilter;
  end;

type
  TPoint3D = record
    X, Y, Z: Single;
  end;

  T3DVertex = record
    Pos: TPoint3D;
    Color: TColor;
  end;

type
  TBall = record
    Position: TPoint3D;
    Radius: Single;
    Color: TColor;
    Active: Boolean;
  end;

type
  TMainForm = class(TForm)
    rightPanel: TPanel;
    leftPanel: TPanel;
    Panel1: TPanel;
    TrackBar1: TTrackBar;
    TrackBar2: TTrackBar;
    Panel2: TPanel;
    TrackBar3: TTrackBar;
    TrackBar4: TTrackBar;
    Panel3: TPanel;
    ButtonUp: TcxButton;
    ButtonDown: TcxButton;
    Button3: TButton;
    cxLabel1: TcxLabel;
    image3D: TPaintBox;
    Hand3d: TCheckBox;
    HandPl: TCheckBox;
    Button4: TButton;
    CheckBox1: TCheckBox;
    Label1: TLabel;
    TimerSendCom: TTimer;
    procedure CloseHost;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure SetCanvasZoomFactor(Canvas: TCanvas; AZoomFactor: Integer);
    procedure ButtonUpClick(Sender: TObject);
    procedure ButtonDownClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure waiteComRx();
    procedure FormShow(Sender: TObject);
    procedure TimerSendComTimer(Sender: TObject);
  private
    { Private-Deklarationen }
    FskeletonEvents, FdepthEvents: TEventDispatcherThread;

    Fsensor: INuiSensor;
    FdepthEvent, FskeletonEvent, FdepthStream: cardinal;
    FTiltAngle: Integer;
    Fbitmap: TBitmap;
    Uformat: NUI_IMAGE_RESOLUTION;

    FMinDepth: Single;
    FMaxDepth: Single;
    FDepthPoints: array of TPoint3D; // Добавьте эту строку
    FDepthPointsCount: Integer; // Счетчик фактических точек
    Fcount: Integer;
    FBalls: array [0 .. 9] of TBall; // Массив шариков
    FLastBallTime: cardinal; // Время создания последнего шарика
    FBallCreationInterval: Integer; // Интервал создания шариков (мс)
    FTouched: Boolean;
    Comm: TComm;
    shexStrFull: String;
    step: integer;
    FCOM_NUMBER: String;
    isConnected: Boolean;
    FPalmScreenX, FPalmScreenY: Integer;
    old_palmScreenX, old_palmScreenY: Integer;
    deltaX, deltaY: Integer;
    FKalmanFilter: TKalmanFilter2D;
    FKalmanInitialized: Boolean;
    old_palmScreenXFiltered, old_palmScreenYFiltered: Integer;
    function openFirstSensor: Boolean;
    procedure eventDispatcher(var msg: TMessage); message WM_USER;

    function GetDepthColor(depthValue: Word): TColor;
    function FindClosestPoint: TPoint3D;
    function Distance3D(p1, p2: TPoint3D): Single;
    function Distance3D2(p1, p2: TPoint3D): Single; inline;
    function Distance3D_SIMD(p1, p2: TPoint3D): Single;
    procedure DrawHandContour(handPoints: TList<TPoint3D>);
    procedure FastHandDetection;
    procedure DrawExplosionEffect(X, Y, Z: Single; Color: TColor);
    procedure SimpleHandDetection;
    procedure FastHandDetection2;
    procedure FastHandDetection3;
    function FindWristPoint(handRegion: TList<TPoint3D>; palmCenter: TPoint3D)
      : TPoint3D;
    function FindForearmPoints(wristPoint, palmCenter: TPoint3D)
      : TList<TPoint3D>;
    function FindElbowPoint(armPoints: TList<TPoint3D>; wristPoint: TPoint3D)
      : TPoint3D;
    function DetermineHandOrientation(palmCenter, elbowPoint: TPoint3D)
      : Boolean;
    procedure NormalizeVector(var Vector: TPoint3D);
    procedure DrawArrow(Canvas: TCanvas; x1, y1, x2, y2: Integer;
      ArrowSize: Integer);
    function DistanceToLine3D(Point, LinePoint, LineDirection
      : TPoint3D): Single;
    function DotProduct3D(Vector1, Vector2: TPoint3D): Single;
    function SubtractPoints3D(Point1, Point2: TPoint3D): TPoint3D;
    procedure OnNewDepthFrame;
    procedure InitializeKalmanFilter;
    procedure UpdateKalmanFilter(var Kalman: TKalmanFilter; Measurement: Single);
    procedure CreateNewBall;
    procedure UpdateBalls;
    procedure DrawBalls;
    function CheckBallCollision(handPoints: TList<TPoint3D>): Boolean;
    function IsHandClosed(handPoints: TList<TPoint3D>; palmCenter: TPoint3D): Boolean;
    procedure OnGet(Sender: TObject; Count: integer);
    procedure CreateP(vport: string);
    procedure SendPalmCoordinatesToESP32(X, Y: Integer; IsClosed: Boolean);
  public
    { Public-Deklarationen }
  end;

var
  MainForm: TMainForm;

implementation

uses NuiImageCamera, NuiSkeleton;

{$R *.dfm}

 const
    HAND_CLOSED_THRESHOLD = 0.28; // Порог для определения сжатой руки

procedure TMainForm.InitializeKalmanFilter;
begin
  // Инициализация фильтра для X координаты
  FKalmanFilter.X.Q := 0.01;  // шум процесса
  FKalmanFilter.X.R := 0.02;   // шум измерения
  FKalmanFilter.X.P := 1.0;   // начальная ковариация
  FKalmanFilter.X.X := 0.0;   // начальная оценка

  // Инициализация фильтра для Y координаты
  FKalmanFilter.Y.Q := 0.01;
  FKalmanFilter.Y.R := 0.1;
  FKalmanFilter.Y.P := 1.0;
  FKalmanFilter.Y.X := 0.0;

  FKalmanInitialized := False;
end;

procedure TMainForm.UpdateKalmanFilter(var Kalman: TKalmanFilter; Measurement: Single);
begin
  // Предсказание
  Kalman.P := Kalman.P + Kalman.Q;

  // Обновление
  Kalman.K := Kalman.P / (Kalman.P + Kalman.R);
  Kalman.X := Kalman.X + Kalman.K * (Measurement - Kalman.X);
  Kalman.P := (1 - Kalman.K) * Kalman.P;
end;

procedure TMainForm.CreateNewBall;
var
  i: Integer;
begin
  // Ищем неактивный шарик
  for i := 0 to High(FBalls) do
  begin
    if not FBalls[i].Active then
    begin
      // Случайная позиция в пределах видимой области
      FBalls[i].Position.X := Random * 4 - 2; // от -2 до 2 метра по X
      FBalls[i].Position.Y := Random * 2 - 1; // от -1 до 1 метра по Y
      FBalls[i].Position.Z := FMinDepth +
        (Random * (FMaxDepth - FMinDepth) * 0.5); // в пределах глубины

      FBalls[i].Radius := 0.15 + Random * 0.15; // радиус 15-30 см
      FBalls[i].Color := RGB(Random(200) + 55, Random(200) + 55,
        Random(200) + 55);
      FBalls[i].Active := True;
      Break;
    end;
  end;
end;

procedure TMainForm.UpdateBalls;
var
  i: Integer;
  currentTime: cardinal;
begin
  currentTime := GetTickCount;

  // Создаем новый шарик, если прошло достаточно времени
  if currentTime - FLastBallTime > cardinal(FBallCreationInterval) then
  begin
    CreateNewBall;
    FLastBallTime := currentTime;
  end;

  // Двигаем шарики вперед (к камере)
  for i := 0 to High(FBalls) do
  begin
    if FBalls[i].Active then
    begin
      // Шарики движутся к камере
      // FBalls[i].Position.Z := FBalls[i].Position.Z - 0.02; // 2 см за кадр

      // Если шарик вышел за пределы видимости, деактивируем его
      // if FBalls[i].Position.Z < FMinDepth then
      // FBalls[i].Active := False;
    end;
  end;
end;

procedure TMainForm.DrawBalls;
var
  i: Integer;
  screenX, screenY: Integer;
  screenRadius: Integer;
  scale: Single;
begin
  scale := TrackBar1.Position / 5;

  for i := 0 to High(FBalls) do
  begin
    if FBalls[i].Active then
    begin
      // Проекция 3D позиции на 2D экран
      screenX := Round(Fbitmap.Width / 2 + FBalls[i].Position.X * scale * 100);
      screenY := Round(Fbitmap.Height / 2 - FBalls[i].Position.Y * scale * 100);
      screenRadius := Round(FBalls[i].Radius * scale * 100);

      // Рисуем шарик
      Fbitmap.Canvas.Brush.Color := FBalls[i].Color;
      Fbitmap.Canvas.Pen.Color := clWhite;
      Fbitmap.Canvas.Pen.Width := 2;
      Fbitmap.Canvas.Ellipse(screenX - screenRadius, screenY - screenRadius,
        screenX + screenRadius, screenY + screenRadius);
    end;
  end;
end;

function TMainForm.CheckBallCollision(handPoints: TList<TPoint3D>): Boolean;
var
  i, j: Integer;
  ballCenter, handPoint: TPoint3D;
  distance, touchRadius: Single;
  collisionDetected: Boolean;
begin
  Result := False;
  collisionDetected := False;

  for i := 0 to High(FBalls) do
  begin
    if FBalls[i].Active then
    begin
      ballCenter := FBalls[i].Position;

      // Проверяем коллизию с каждой точкой руки
      for j := 0 to handPoints.Count - 1 do
      begin
        handPoint := handPoints[j];
        distance := Distance3D(ballCenter, handPoint);

        // Если расстояние меньше радиуса шарика + небольшой допуск
        if distance < FBalls[i].Radius + 0.05 then
        begin
          FBalls[i].Active := False; // Лопаем шарик
          collisionDetected := True;

          // Визуальный эффект взрыва
          DrawExplosionEffect(ballCenter.X, ballCenter.Y, ballCenter.Z,
            FBalls[i].Color);

          inc(Fcount);
          cxLabel1.Caption := inttostr(Fcount);

          Break;
        end;
      end;
    end;
  end;

  if collisionDetected then
  begin
    // Можно добавить звуковой эффект здесь
    Beep; // Простой звук
    Result := True;
  end;

end;

procedure TMainForm.eventDispatcher(var msg: TMessage);
begin
  // if msg.WParam = Integer(FskeletonEvents) then
  // OnNewSkeletonFrame
  // else
  if msg.WParam = Integer(FdepthEvents) then
    OnNewDepthFrame;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CloseHost;
end;

procedure TMainForm.waiteComRx();
var
  Tc: Cardinal;
  Tc2: Cardinal;
begin
  //Ожидаем приход пакета
  Tc := GetTickCount;
  while true do
  begin
    Tc2 := GetTickCount;

    if Tc2 >= (Tc + 236) then //Если нет ответа 0.24 сек считаем что его и не будет
    begin
      break;
    end;

  end;
end;

procedure TMainForm.CloseHost;
begin
  if Comm <> nil then
  begin
    try
      Comm.Close;
      Comm.Free;
      Comm := nil;
      waiteComRx();
    except
    end;
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  i: Integer;
  ini: TIniFile;
begin
  FskeletonEvent := INVALID_HANDLE_VALUE;
  FdepthEvent := INVALID_HANDLE_VALUE;
  FdepthStream := INVALID_HANDLE_VALUE;
  FTiltAngle := 12;
  FTouched := false;

  // Инициализация игры
  // for i := 0 to High(FBalls) do
  // FBalls[i].Active := False;

  // FLastBallTime := GetTickCount;
  // FBallCreationInterval := 2000; // Новый шарик каждые 2 секунды
  // Randomize; // Инициализация генератора случайных чисел
  DoubleBuffered := True;

  if not LoadNuiLibrary then
    exit;

  ini := TIniFile.Create(ChangeFileExt(Application.ExeName, '.INI'));;
  try
    FCOM_NUMBER := ini.ReadString('CONNECTION', 'COM', '1');
  finally
    ini.Free;
  end;

  openFirstSensor;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  if assigned(Fsensor) then
  begin
    Fsensor.NuiSkeletonTrackingDisable;
    Fsensor.NuiShutdown;
  end;

  if FskeletonEvent <> INVALID_HANDLE_VALUE then
    CloseHandle(FskeletonEvent);
  if FdepthEvent <> INVALID_HANDLE_VALUE then
    CloseHandle(FdepthEvent);

  if assigned(FskeletonEvents) then
  begin
    FskeletonEvents.Terminate;
    FskeletonEvents.WaitFor;
    FskeletonEvents.Free;
  end;
  if assigned(FdepthEvents) then
  begin
    FdepthEvents.Terminate;
    FdepthEvents.WaitFor;
    FdepthEvents.Free;
  end;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
   if Comm = nil then
      CreateP('\\.\COM' + FCOM_NUMBER);
  MainForm.Width := 656;
  MainForm.Height := 519+Panel3.Height + Panel2.Height + Panel1.Height;
end;

function TMainForm.GetDepthColor(depthValue: Word): TColor;
var
  intensity: Byte;
  depthInMeters: Single;
begin
  // Убираем биты игрока
  depthValue := depthValue and not NUI_IMAGE_PLAYER_INDEX_MASK;

  // Преобразуем глубину в диапазон 0-255
  depthInMeters := (depthValue shr NUI_IMAGE_PLAYER_INDEX_SHIFT) / 1000.0;

  // Ближние объекты - теплые цвета, дальние - холодные
  if depthInMeters < 1.0 then // Ближе 1 метра
  begin
    intensity := Round(255 * (1.0 - depthInMeters));
    Result := RGB(intensity, intensity div 2, 0); // От желтого к красному
  end
  else if depthInMeters < 3.0 then // От 1 до 3 метров
  begin
    intensity := Round(255 * (depthInMeters - 1.0) / 2.0);
    Result := RGB(255 - intensity, intensity, 0); // От красного к зеленому
  end
  else // Дальше 3 метров
  begin
    intensity := Round(255 * Min(1.0, (depthInMeters - 3.0) / 2.0));
    Result := RGB(0, 255 - intensity, intensity); // От зеленого к синему
  end;
end;

function TMainForm.FindClosestPoint: TPoint3D;
var
  i: Integer;
  minDepth: Single;
begin
  // Инициализируем результатом с максимальной глубиной
  Result.X := 0;
  Result.Y := 0;
  Result.Z := FMaxDepth; // Начинаем с максимальной глубины

  if FDepthPointsCount = 0 then
    exit;

  minDepth := FMaxDepth;

  for i := 0 to FDepthPointsCount - 1 do
  begin
    if FDepthPoints[i].Z < minDepth then
    begin
      minDepth := FDepthPoints[i].Z;
      Result := FDepthPoints[i];
    end;
  end;

  // Если не нашли точек в диапазоне, возвращаем нулевую точку
  if minDepth = FMaxDepth then
  begin
    Result.X := 0;
    Result.Y := 0;
    Result.Z := 0;
  end;
end;

function TMainForm.Distance3D(p1, p2: TPoint3D): Single;
begin
  Result := Sqrt(Sqr(p1.X - p2.X) + Sqr(p1.Y - p2.Y) + Sqr(p1.Z - p2.Z));
end;

function TMainForm.Distance3D2(p1, p2: TPoint3D): Single;
begin
  Result := Sqrt(Sqr(p1.X - p2.X) + Sqr(p1.Y - p2.Y) + Sqr(p1.Z - p2.Z));
end;

function TMainForm.Distance3D_SIMD(p1, p2: TPoint3D): Single;
var
  v1, v2: TVector3D;
begin
  v1 := Vector3D(p1.X, p1.Y, p1.Z);
  v2 := Vector3D(p2.X, p2.Y, p2.Z);
  Result := (v1 - v2).Length;
end;

procedure TMainForm.DrawExplosionEffect(X, Y, Z: Single; Color: TColor);
var
  screenX, screenY: Integer;
  scale: Single;
  i: Integer;
  Radius: Integer;
begin
  scale := TrackBar1.Position / 5;
  screenX := Round(Fbitmap.Width / 2 + X * scale * 100);
  screenY := Round(Fbitmap.Height / 2 - Y * scale * 100);

  // Рисуем несколько концентрических кругов для эффекта взрыва
  for i := 1 to 3 do
  begin
    Radius := i * 10;
    Fbitmap.Canvas.Pen.Color := RGB(Min(255, GetRValue(Color) + 50 * i),
      Min(255, GetGValue(Color) + 50 * i), Min(255, GetBValue(Color) + 50 * i));
    Fbitmap.Canvas.Pen.Width := 2;
    Fbitmap.Canvas.Brush.Style := bsClear;
    Fbitmap.Canvas.Ellipse(screenX - Radius, screenY - Radius, screenX + Radius,
      screenY + Radius);
  end;
end;

procedure TMainForm.DrawHandContour(handPoints: TList<TPoint3D>);
var
  i: Integer;
  screenX, screenY: Integer;
  scale: Single;
begin
  if handPoints.Count = 0 then
    exit;

  scale := TrackBar1.Position / 5;

  // Просто рисуем все точки кисти
  for i := 0 to handPoints.Count - 1 do
  begin
    screenX := Round(Fbitmap.Width / 2 + handPoints[i].X * scale * 100);
    screenY := Round(Fbitmap.Height / 2 - handPoints[i].Y * scale * 100);

    if (i mod 10 = 0) then // Рисуем каждую 10-ю точку для производительности
    begin
      Fbitmap.Canvas.Pen.Color := clYellow;
      Fbitmap.Canvas.Pen.Width := Round(5 * scale);
      Fbitmap.Canvas.Ellipse(screenX - 2, screenY - 2, screenX + 2,
        screenY + 2);
    end;
  end;
end;

procedure TMainForm.FastHandDetection3;
const
  colors: array [0 .. 4] of TColor = (clRed, clYellow, clGreen, clBlue,
    clFuchsia);
var
  minDepthPoint: TPoint3D;
  handRegion: TList<TPoint3D>;
  searchRadius: Single;
  i: Integer;
  scale: Single;
  fingerPoints: array [0 .. 4] of TPoint3D;
  fingerCount, stripIndex, j, screenX, screenY: Integer;
  minX, maxX, minY, maxY: Single;
  stripHeight: double;
  currentStrips: array [0 .. 4] of TList<TPoint3D>;
  minZ: Single;
  palmCenter: TPoint3D;
  palmScreenX, palmScreenY: Integer;
  fingerScreenX, fingerScreenY: Integer;
  lighterColor: COLORREF;
begin
  // Находим самую близкую точку
  minDepthPoint := FindClosestPoint;

  if minDepthPoint.Z > FMaxDepth then
    exit;

  // Собираем точки руки
  handRegion := TList<TPoint3D>.Create;
  searchRadius := TrackBar1.Position / 10;

  for i := 0 to FDepthPointsCount - 1 do
  begin
    if Distance3D2(FDepthPoints[i], minDepthPoint) < searchRadius then
      handRegion.Add(FDepthPoints[i]);
  end;

  if handRegion.Count > 30 then
  begin
    scale := TrackBar1.Position / 5;

    // Вычисляем центр ладони (среднее арифметическое всех точек)
    palmCenter.X := 0;
    palmCenter.Y := 0;
    palmCenter.Z := 0;

    for i := 0 to handRegion.Count - 1 do
    begin
      palmCenter.X := palmCenter.X + handRegion[i].X;
      palmCenter.Y := palmCenter.Y + handRegion[i].Y;
      palmCenter.Z := palmCenter.Z + handRegion[i].Z;
    end;

    palmCenter.X := palmCenter.X / handRegion.Count;
    palmCenter.Y := palmCenter.Y / handRegion.Count;
    palmCenter.Z := palmCenter.Z / handRegion.Count;

    // Координаты центра ладони на экране
    palmScreenX := Round(Fbitmap.Width / 2 + palmCenter.X * scale * 100);
    palmScreenY := Round(Fbitmap.Height / 2 - palmCenter.Y * scale * 100);

    // Находим границы руки для разделения на пальцы
    minX := handRegion[0].X;
    maxX := handRegion[0].X;
    minY := handRegion[0].Y;
    maxY := handRegion[0].Y;

    for i := 1 to handRegion.Count - 1 do
    begin
      if handRegion[i].X < minX then
        minX := handRegion[i].X;
      if handRegion[i].X > maxX then
        maxX := handRegion[i].X;
      if handRegion[i].Y < minY then
        minY := handRegion[i].Y;
      if handRegion[i].Y > maxY then
        maxY := handRegion[i].Y;
    end;

    // Делим область на 5 горизонтальных полос (предполагая, что это пальцы)
    stripHeight := (maxY - minY) / 5;

    for i := 0 to 4 do
      currentStrips[i] := TList<TPoint3D>.Create;

    try
      // Распределяем точки по полосам
      for i := 0 to handRegion.Count - 1 do
      begin
        stripIndex := Trunc((handRegion[i].Y - minY) / stripHeight);
        if stripIndex > 4 then
          stripIndex := 4;
        if stripIndex < 0 then
          stripIndex := 0;
        currentStrips[stripIndex].Add(handRegion[i]);
      end;

      // Для каждой полосы находим самую верхнюю точку (кончик пальца)
      fingerCount := 0;
      for i := 0 to 4 do
      begin
        if currentStrips[i].Count > 5 then // Минимум 5 точек в полосе
        begin
          // Находим точку с минимальной Z в полосе
          minZ := currentStrips[i][0].Z;
          fingerPoints[fingerCount] := currentStrips[i][0];

          for j := 1 to currentStrips[i].Count - 1 do
          begin
            if currentStrips[i][j].Z < minZ then
            begin
              minZ := currentStrips[i][j].Z;
              fingerPoints[fingerCount] := currentStrips[i][j];
            end;
          end;

          inc(fingerCount);
        end;
      end;


      if HandPl.Checked then
      begin

        // 1. Сначала рисуем линии от центра ладони к пальцам
        Fbitmap.Canvas.Pen.Width := 2;
        Fbitmap.Canvas.Pen.Style := psSolid;
        Fbitmap.Canvas.Pen.Color := clWhite;

        for i := 0 to fingerCount - 1 do
        begin
          fingerScreenX := Round(Fbitmap.Width / 2 + fingerPoints[i].X *
            scale * 100);
          fingerScreenY := Round(Fbitmap.Height / 2 - fingerPoints[i].Y *
            scale * 100);

          // Линия от центра ладони к пальцу
          Fbitmap.Canvas.MoveTo(palmScreenX, palmScreenY);
          Fbitmap.Canvas.LineTo(fingerScreenX, fingerScreenY);
        end;

      end;

      // 2. Рисуем центр ладони (очень жирная точка)
      Fbitmap.Canvas.Pen.Color := clWhite;
      Fbitmap.Canvas.Pen.Width := 3;
      Fbitmap.Canvas.Brush.Color := clYellow;

      // Большой круг для центра ладони
     // Fbitmap.Canvas.Ellipse(palmScreenX - 20, palmScreenY - 20,
     //   palmScreenX + 20, palmScreenY + 20);

      FTouched := IsHandClosed(handRegion, palmCenter);

      palmScreenX := Round(Fbitmap.Width / 2 + palmCenter.X * scale * 100);
      palmScreenY := Round(Fbitmap.Height / 2 - palmCenter.Y * scale * 100);

      deltaX := palmScreenX-old_palmScreenX;
      deltaY := palmScreenY-old_palmScreenY;

      Label1.Caption := inttostr(deltaX)+ ' x ' + inttostr(deltaY);

      old_palmScreenX := palmScreenX;
      old_palmScreenY := palmScreenY;

   //   OutputDebugString(PChar(Format('Sent: T %d %d %d', [X, Y, TouchState])));

      TimerSendCom.Enabled := CheckBox1.Checked;
      // Внутренний круг для лучшей видимости



      if FTouched then
        begin
          Fbitmap.Canvas.Pen.Color := clRed;
          Fbitmap.Canvas.Pen.Width := 2;
          Fbitmap.Canvas.Brush.Color := clRed;
         // Fbitmap.Canvas.TextOut(palmScreenX - 25, palmScreenY - 40, 'CLOSED');
         Fbitmap.Canvas.Pen.Color := clWhite;
        end
        else
        begin
          Fbitmap.Canvas.Pen.Color := clYellow;
          Fbitmap.Canvas.Pen.Width := 2;
          Fbitmap.Canvas.Brush.Color := clYellow;
         // Fbitmap.Canvas.TextOut(palmScreenX - 20, palmScreenY - 40, 'OPEN');
         Fbitmap.Canvas.Pen.Color := clBlack;
        end;


      Fbitmap.Canvas.Ellipse(palmScreenX - 12, palmScreenY - 12,
        palmScreenX + 12, palmScreenY + 12);

      // Крестик для акцента

      Fbitmap.Canvas.Pen.Width := 2;
      Fbitmap.Canvas.MoveTo(palmScreenX - 8, palmScreenY);
      Fbitmap.Canvas.LineTo(palmScreenX + 8, palmScreenY);
      Fbitmap.Canvas.MoveTo(palmScreenX, palmScreenY - 8);
      Fbitmap.Canvas.LineTo(palmScreenX, palmScreenY + 8);

      if HandPl.Checked then
      begin

        // 3. Рисуем пальцы поверх линий
        for i := 0 to fingerCount - 1 do
        begin
          screenX := Round(Fbitmap.Width / 2 + fingerPoints[i].X * scale * 100);
          screenY := Round(Fbitmap.Height / 2 - fingerPoints[i].Y * scale * 100);

          // Внешний круг пальца
          Fbitmap.Canvas.Pen.Color := colors[i];
          Fbitmap.Canvas.Pen.Width := 2;
          Fbitmap.Canvas.Brush.Color := colors[i];
          Fbitmap.Canvas.Ellipse(screenX - 15, screenY - 15, screenX + 15,
            screenY + 15);

          // Внутренний круг для лучшей видимости
          lighterColor := RGB(Min(255, GetRValue(colors[i]) + 50),
            Min(255, GetGValue(colors[i]) + 50),
            Min(255, GetBValue(colors[i]) + 50));

          Fbitmap.Canvas.Pen.Color := lighterColor;
          Fbitmap.Canvas.Brush.Color := lighterColor;
          Fbitmap.Canvas.Ellipse(screenX - 10, screenY - 10, screenX + 10,
            screenY + 10);

          // Номер пальца
          Fbitmap.Canvas.Font.Color := clBlack;
          Fbitmap.Canvas.Font.Size := 10;
          Fbitmap.Canvas.Font.Style := [fsBold];
          Fbitmap.Canvas.TextOut(screenX - 5, screenY - 7, inttostr(i + 1));
        end;

      end;

    finally
      for i := 0 to 4 do
        currentStrips[i].Free;
    end;

  end;

  handRegion.Free;
end;

procedure TMainForm.FastHandDetection;
const
  colors: array [0 .. 4] of TColor = (clRed, clYellow, clGreen, clBlue,
    clFuchsia);
var
  minDepthPoint: TPoint3D;
  handRegion: TList<TPoint3D>;
  searchRadius: Single;
  i: Integer;
  scale: Single;
  fingerPoints: array [0 .. 4] of TPoint3D;
  fingerCount, stripIndex, j, screenX, screenY: Integer;
  minX, maxX, minY, maxY: Single;
  stripHeight: double;
  currentStrips: array [0 .. 4] of TList<TPoint3D>;
  minZ: Single;
  palmCenter: TPoint3D;
  palmScreenX, palmScreenY: Integer;
  palmScreenXFiltered, palmScreenYFiltered: Integer;
  fingerScreenX, fingerScreenY: Integer;
  lighterColor: COLORREF;
begin
  // Инициализация фильтра Кальмана при первом запуске
  if not FKalmanInitialized then
  begin
    InitializeKalmanFilter;
    FKalmanInitialized := True;
  end;

  // Находим самую близкую точку
  minDepthPoint := FindClosestPoint;

  if minDepthPoint.Z > FMaxDepth then
    exit;

  // Собираем точки руки
  handRegion := TList<TPoint3D>.Create;
  searchRadius := TrackBar1.Position / 10;

  for i := 0 to FDepthPointsCount - 1 do
  begin
    if Distance3D2(FDepthPoints[i], minDepthPoint) < searchRadius then
      handRegion.Add(FDepthPoints[i]);
  end;

  if handRegion.Count > 30 then
  begin
    scale := TrackBar1.Position / 5;

    // Вычисляем центр ладони (среднее арифметическое всех точек)
    palmCenter.X := 0;
    palmCenter.Y := 0;
    palmCenter.Z := 0;

    for i := 0 to handRegion.Count - 1 do
    begin
      palmCenter.X := palmCenter.X + handRegion[i].X;
      palmCenter.Y := palmCenter.Y + handRegion[i].Y;
      palmCenter.Z := palmCenter.Z + handRegion[i].Z;
    end;

    palmCenter.X := palmCenter.X / handRegion.Count;
    palmCenter.Y := palmCenter.Y / handRegion.Count;
    palmCenter.Z := palmCenter.Z / handRegion.Count;

    // Координаты центра ладони на экране (нефильтрованные)
    palmScreenX := Round(Fbitmap.Width / 2 + palmCenter.X * scale * 100);
    palmScreenY := Round(Fbitmap.Height / 2 - palmCenter.Y * scale * 100);

    // Применяем фильтр Кальмана к координатам
    UpdateKalmanFilter(FKalmanFilter.X, palmScreenX);
    UpdateKalmanFilter(FKalmanFilter.Y, palmScreenY);

    // Получаем фильтрованные координаты
    palmScreenXFiltered := Round(FKalmanFilter.X.X);
    palmScreenYFiltered := Round(FKalmanFilter.Y.X);

    // Используйте palmScreenXFiltered и palmScreenYFiltered вместо palmScreenX и palmScreenY
    // в остальной части кода...

    // Находим границы руки для разделения на пальцы
    minX := handRegion[0].X;
    maxX := handRegion[0].X;
    minY := handRegion[0].Y;
    maxY := handRegion[0].Y;

    for i := 1 to handRegion.Count - 1 do
    begin
      if handRegion[i].X < minX then
        minX := handRegion[i].X;
      if handRegion[i].X > maxX then
        maxX := handRegion[i].X;
      if handRegion[i].Y < minY then
        minY := handRegion[i].Y;
      if handRegion[i].Y > maxY then
        maxY := handRegion[i].Y;
    end;

    // Делим область на 5 горизонтальных полос
    stripHeight := (maxY - minY) / 5;

    for i := 0 to 4 do
      currentStrips[i] := TList<TPoint3D>.Create;

    try
      // Распределяем точки по полосам
      for i := 0 to handRegion.Count - 1 do
      begin
        stripIndex := Trunc((handRegion[i].Y - minY) / stripHeight);
        if stripIndex > 4 then
          stripIndex := 4;
        if stripIndex < 0 then
          stripIndex := 0;
        currentStrips[stripIndex].Add(handRegion[i]);
      end;

      // Для каждой полосы находим самую верхнюю точку
      fingerCount := 0;
      for i := 0 to 4 do
      begin
        if currentStrips[i].Count > 5 then
        begin
          minZ := currentStrips[i][0].Z;
          fingerPoints[fingerCount] := currentStrips[i][0];

          for j := 1 to currentStrips[i].Count - 1 do
          begin
            if currentStrips[i][j].Z < minZ then
            begin
              minZ := currentStrips[i][j].Z;
              fingerPoints[fingerCount] := currentStrips[i][j];
            end;
          end;

          inc(fingerCount);
        end;
      end;

      if HandPl.Checked then
      begin
        // Рисуем линии от центра ладони к пальцам (используем фильтрованные координаты)
        Fbitmap.Canvas.Pen.Width := 2;
        Fbitmap.Canvas.Pen.Style := psSolid;
        Fbitmap.Canvas.Pen.Color := clWhite;

        for i := 0 to fingerCount - 1 do
        begin
          fingerScreenX := Round(Fbitmap.Width / 2 + fingerPoints[i].X *
            scale * 100);
          fingerScreenY := Round(Fbitmap.Height / 2 - fingerPoints[i].Y *
            scale * 100);

          // Линия от центра ладони к пальцу
          Fbitmap.Canvas.MoveTo(palmScreenXFiltered, palmScreenYFiltered);
          Fbitmap.Canvas.LineTo(fingerScreenX, fingerScreenY);
        end;
      end;

      FTouched := IsHandClosed(handRegion, palmCenter);

      // Отображаем дельту между отфильтрованными и нефильтрованными координатами
      deltaX := palmScreenXFiltered - old_palmScreenXFiltered;
      deltaY := palmScreenYFiltered - old_palmScreenYFiltered;

      Label1.Caption := inttostr(deltaX)+ ' x ' + inttostr(deltaY);

      old_palmScreenXFiltered := palmScreenXFiltered;
      old_palmScreenYFiltered := palmScreenYFiltered;

      TimerSendCom.Enabled := CheckBox1.Checked;

      // Рисуем центр ладони с фильтрованными координатами
      if FTouched then
      begin
        Fbitmap.Canvas.Pen.Color := clRed;
        Fbitmap.Canvas.Pen.Width := 2;
        Fbitmap.Canvas.Brush.Color := clRed;
      end
      else
      begin
        Fbitmap.Canvas.Pen.Color := clYellow;
        Fbitmap.Canvas.Pen.Width := 2;
        Fbitmap.Canvas.Brush.Color := clYellow;
      end;

      // Круг центра ладони
      Fbitmap.Canvas.Ellipse(palmScreenXFiltered - 12, palmScreenYFiltered - 12,
        palmScreenXFiltered + 12, palmScreenYFiltered + 12);

      // Крестик для акцента
      Fbitmap.Canvas.Pen.Width := 2;
      Fbitmap.Canvas.MoveTo(palmScreenXFiltered - 8, palmScreenYFiltered);
      Fbitmap.Canvas.LineTo(palmScreenXFiltered + 8, palmScreenYFiltered);
      Fbitmap.Canvas.MoveTo(palmScreenXFiltered, palmScreenYFiltered - 8);
      Fbitmap.Canvas.LineTo(palmScreenXFiltered, palmScreenYFiltered + 8);

      // Показываем также нефильтрованный центр (меньшим кругом)
      Fbitmap.Canvas.Pen.Color := clBlue;
      Fbitmap.Canvas.Pen.Width := 1;
      Fbitmap.Canvas.Brush.Style := bsClear;
      Fbitmap.Canvas.Ellipse(palmScreenX - 6, palmScreenY - 6,
        palmScreenX + 6, palmScreenY + 6);

      if HandPl.Checked then
      begin
        // Рисуем пальцы
        for i := 0 to fingerCount - 1 do
        begin
          screenX := Round(Fbitmap.Width / 2 + fingerPoints[i].X * scale * 100);
          screenY := Round(Fbitmap.Height / 2 - fingerPoints[i].Y * scale * 100);

          Fbitmap.Canvas.Pen.Color := colors[i];
          Fbitmap.Canvas.Pen.Width := 2;
          Fbitmap.Canvas.Brush.Color := colors[i];
          Fbitmap.Canvas.Ellipse(screenX - 15, screenY - 15, screenX + 15,
            screenY + 15);

          lighterColor := RGB(Min(255, GetRValue(colors[i]) + 50),
            Min(255, GetGValue(colors[i]) + 50),
            Min(255, GetBValue(colors[i]) + 50));

          Fbitmap.Canvas.Pen.Color := lighterColor;
          Fbitmap.Canvas.Brush.Color := lighterColor;
          Fbitmap.Canvas.Ellipse(screenX - 10, screenY - 10, screenX + 10,
            screenY + 10);

          Fbitmap.Canvas.Font.Color := clBlack;
          Fbitmap.Canvas.Font.Size := 10;
          Fbitmap.Canvas.Font.Style := [fsBold];
          Fbitmap.Canvas.TextOut(screenX - 5, screenY - 7, inttostr(i + 1));
        end;
      end;

    finally
      for i := 0 to 4 do
        currentStrips[i].Free;
    end;
  end;

  handRegion.Free;
end;


procedure TMainForm.SimpleHandDetection;
var
  minDepthPoint: TPoint3D;
  handRegion: TList<TPoint3D>;
  searchRadius: Single;
  i: Integer;
  handCenter: TPoint3D;
begin
  // Находим самую близкую точку (скорее всего, кисть)
  minDepthPoint := FindClosestPoint;

  if minDepthPoint.Z > FMaxDepth then
    exit;

  // Собираем все точки в радиусе от ближайшей
  handRegion := TList<TPoint3D>.Create;
  searchRadius := 2.25; // 15 см радиус

  for i := 0 to High(FDepthPoints) do
  begin
    if Distance3D_SIMD(FDepthPoints[i], minDepthPoint) < searchRadius then
      handRegion.Add(FDepthPoints[i]);
  end;

  if handRegion.Count > 30 then // Минимум 30 точек
  begin
    // Рисуем контур кисти
    // DrawHandContour(handRegion);
    // ExtremeSimpleHandDetection;
    // Проверяем коллизии с шариками
    // CheckBallCollision(handRegion);
    FastHandDetection;
  end;

  handRegion.Free;
end;


// -----------

procedure TMainForm.FastHandDetection2;
const
  colors: array [0 .. 4] of TColor = (clRed, clYellow, clGreen, clBlue,
    clFuchsia);
var
  minDepthPoint: TPoint3D;
  handRegion: TList<TPoint3D>;
  searchRadius: Single;
  i: Integer;
  scale: Single;
  fingerPoints: array [0 .. 4] of TPoint3D;
  fingerCount, stripIndex, j, screenX, screenY: Integer;
  minX, maxX, minY, maxY: Single;
  stripHeight: double;
  currentStrips: array [0 .. 4] of TList<TPoint3D>;
  minZ: Single;
  palmCenter: TPoint3D;
  palmScreenX, palmScreenY: Integer;
  fingerScreenX, fingerScreenY: Integer;
  lighterColor: COLORREF;

  // Новые переменные для определения локтя и вектора
  wristPoint, elbowPoint: TPoint3D;
  handDirectionVector: TPoint3D;
  armPoints: TList<TPoint3D>;
  isLeftHand: Boolean;
  handVectorScreenX, handVectorScreenY: Integer;
begin
  // Находим самую близкую точку
  minDepthPoint := FindClosestPoint;

  if minDepthPoint.Z > FMaxDepth then
    exit;

  // Собираем точки руки
  handRegion := TList<TPoint3D>.Create;
  searchRadius := TrackBar1.Position / 10;

  for i := 0 to FDepthPointsCount - 1 do
  begin
    if Distance3D2(FDepthPoints[i], minDepthPoint) < searchRadius then
      handRegion.Add(FDepthPoints[i]);
  end;

  if handRegion.Count > 30 then
  begin
    scale := TrackBar1.Position / 5;

    // Вычисляем центр ладони (среднее арифметическое всех точек)
    palmCenter.X := 0;
    palmCenter.Y := 0;
    palmCenter.Z := 0;

    for i := 0 to handRegion.Count - 1 do
    begin
      palmCenter.X := palmCenter.X + handRegion[i].X;
      palmCenter.Y := palmCenter.Y + handRegion[i].Y;
      palmCenter.Z := palmCenter.Z + handRegion[i].Z;
    end;

    palmCenter.X := palmCenter.X / handRegion.Count;
    palmCenter.Y := palmCenter.Y / handRegion.Count;
    palmCenter.Z := palmCenter.Z / handRegion.Count;

    // === НОВЫЙ КОД: Определение вектора направления руки ===

    // 1. Определяем точку запястья (ближайшая к телу точка на границе кисти)
    wristPoint := FindWristPoint(handRegion, palmCenter);

    // 2. Собираем точки предплечья для поиска локтя
    armPoints := FindForearmPoints(wristPoint, palmCenter);

    // 3. Находим точку локтя (самая далекая от запястья точка предплечья)
    elbowPoint := FindElbowPoint(armPoints, wristPoint);

    // 4. Вычисляем вектор направления от локтя к ладони
    handDirectionVector.X := palmCenter.X - elbowPoint.X;
    handDirectionVector.Y := palmCenter.Y - elbowPoint.Y;
    handDirectionVector.Z := palmCenter.Z - elbowPoint.Z;

    // Нормализуем вектор (делаем длину = 1)
    NormalizeVector(handDirectionVector);

    // 5. Определяем, левая это или правая рука
    isLeftHand := DetermineHandOrientation(palmCenter, elbowPoint);

    // Освобождаем память
    armPoints.Free;
    // === КОНЕЦ НОВОГО КОДА ===

    // Координаты центра ладони на экране
    palmScreenX := Round(Fbitmap.Width / 2 + palmCenter.X * scale * 100);
    palmScreenY := Round(Fbitmap.Height / 2 - palmCenter.Y * scale * 100);

    // Координаты локтя на экране
    screenX := Round(Fbitmap.Width / 2 + elbowPoint.X * scale * 100);
    screenY := Round(Fbitmap.Height / 2 - elbowPoint.Y * scale * 100);

    // === Отрисовка вектора направления руки ===
    Fbitmap.Canvas.Pen.Width := 3;
    Fbitmap.Canvas.Pen.Color := clAqua;

    // Линия от локтя к центру ладони
    Fbitmap.Canvas.MoveTo(screenX, screenY);
    Fbitmap.Canvas.LineTo(palmScreenX, palmScreenY);

    // Стрелка на конце вектора
    DrawArrow(Fbitmap.Canvas, screenX, screenY, palmScreenX, palmScreenY, 15);

    // Точка локтя
    Fbitmap.Canvas.Pen.Color := clLime;
    Fbitmap.Canvas.Brush.Color := clLime;
    Fbitmap.Canvas.Ellipse(screenX - 10, screenY - 10, screenX + 10,
      screenY + 10);

    // Подпись вектора
    // Fbitmap.Canvas.Font.Color := clAqua;
    // Fbitmap.Canvas.Font.Size := 12;
    // Fbitmap.Canvas.Font.Style := [fsBold];
    // Fbitmap.Canvas.TextOut(palmScreenX + 10, palmScreenY - 20,
    // Format('Vector: (%.2f, %.2f, %.2f)',
    // [handDirectionVector.X, handDirectionVector.Y, handDirectionVector.Z]));

    // Подпись для руки
    if isLeftHand then
      Fbitmap.Canvas.TextOut(palmScreenX + 10, palmScreenY - 40, 'Left Hand')
    else
      Fbitmap.Canvas.TextOut(palmScreenX + 10, palmScreenY - 40, 'Right Hand');

    // ... остальной код для пальцев и центра ладони ...

  end;

  handRegion.Free;
end;

// === Вспомогательные функции ===

function TMainForm.FindWristPoint(handRegion: TList<TPoint3D>;
  palmCenter: TPoint3D): TPoint3D;
var
  i: Integer;
  maxDistance, distance: Single;
  wristCandidate: TPoint3D;
  avgX: Single;
begin
  // Находим среднее значение X для определения стороны
  avgX := 0;
  for i := 0 to handRegion.Count - 1 do
    avgX := avgX + handRegion[i].X;
  avgX := avgX / handRegion.Count;

  // Ищем точку запястья как самую далекую от центра ладони в сторону от тела
  maxDistance := 0;
  Result := handRegion[0];

  for i := 0 to handRegion.Count - 1 do
  begin
    // Точки, которые дальше от тела (по X) чем центр ладони
    if (handRegion[i].X > palmCenter.X) and (avgX > palmCenter.X) or
      (handRegion[i].X < palmCenter.X) and (avgX < palmCenter.X) then
    begin
      distance := Distance3D2(handRegion[i], palmCenter);
      if distance > maxDistance then
      begin
        maxDistance := distance;
        Result := handRegion[i];
      end;
    end;
  end;
end;

function TMainForm.FindForearmPoints(wristPoint, palmCenter: TPoint3D)
  : TList<TPoint3D>;
var
  i: Integer;
  armDirection: TPoint3D;
  distanceToLine: Single;
begin
  Result := TList<TPoint3D>.Create;

  // Направление от запястья в сторону от ладони
  armDirection.X := wristPoint.X - palmCenter.X;
  armDirection.Y := wristPoint.Y - palmCenter.Y;
  armDirection.Z := wristPoint.Z - palmCenter.Z;
  NormalizeVector(armDirection);

  // Ищем точки вдоль направления предплечья
  for i := 0 to FDepthPointsCount - 1 do
  begin
    // Проверяем расстояние до линии, идущей от запястья
    distanceToLine := DistanceToLine3D(FDepthPoints[i], wristPoint,
      armDirection);

    if distanceToLine < 0.05 then // Пороговое значение
    begin
      // Проверяем, что точка находится за запястьем (в сторону от ладони)
      if DotProduct3D(SubtractPoints3D(FDepthPoints[i], wristPoint),
        armDirection) > 0 then
      begin
        Result.Add(FDepthPoints[i]);
      end;
    end;
  end;
end;

function TMainForm.FindElbowPoint(armPoints: TList<TPoint3D>;
  wristPoint: TPoint3D): TPoint3D;
var
  i: Integer;
  maxDistance, distance: Single;
begin
  if armPoints.Count = 0 then
  begin
    // Если не нашли точек предплечья, используем точку смещенную от запястья
    Result.X := wristPoint.X - 0.1;
    Result.Y := wristPoint.Y;
    Result.Z := wristPoint.Z;
    exit;
  end;

  maxDistance := 0;
  Result := armPoints[0];

  for i := 0 to armPoints.Count - 1 do
  begin
    distance := Distance3D2(armPoints[i], wristPoint);
    if distance > maxDistance then
    begin
      maxDistance := distance;
      Result := armPoints[i];
    end;
  end;
end;

function TMainForm.DetermineHandOrientation(palmCenter,
  elbowPoint: TPoint3D): Boolean;
begin
  // Определяем, левая это или правая рука
  // Если локоть находится слева от ладони (по X), то это правая рука
  Result := elbowPoint.X < palmCenter.X;
end;

procedure TMainForm.NormalizeVector(var Vector: TPoint3D);
var
  Length: Single;
begin
  Length := Sqrt(Vector.X * Vector.X + Vector.Y * Vector.Y + Vector.Z *
    Vector.Z);
  if Length > 0 then
  begin
    Vector.X := Vector.X / Length;
    Vector.Y := Vector.Y / Length;
    Vector.Z := Vector.Z / Length;
  end;
end;

function TMainForm.DotProduct3D(Vector1, Vector2: TPoint3D): Single;
begin
  Result := Vector1.X * Vector2.X + Vector1.Y * Vector2.Y + Vector1.Z *
    Vector2.Z;
end;

function TMainForm.SubtractPoints3D(Point1, Point2: TPoint3D): TPoint3D;
begin
  Result.X := Point1.X - Point2.X;
  Result.Y := Point1.Y - Point2.Y;
  Result.Z := Point1.Z - Point2.Z;
end;

procedure TMainForm.TimerSendComTimer(Sender: TObject);
begin
  TimerSendCom.Enabled := False;
  SendPalmCoordinatesToESP32(deltaX*2, deltaY*3, FTouched);
 // TimerSendCom.Enabled := True;
end;

function TMainForm.DistanceToLine3D(Point, LinePoint, LineDirection
  : TPoint3D): Single;
var
  crossProduct: TPoint3D;
begin
  // Вычисляем расстояние от точки до линии
  crossProduct.X := (Point.Y - LinePoint.Y) * LineDirection.Z -
    (Point.Z - LinePoint.Z) * LineDirection.Y;
  crossProduct.Y := (Point.Z - LinePoint.Z) * LineDirection.X -
    (Point.X - LinePoint.X) * LineDirection.Z;
  crossProduct.Z := (Point.X - LinePoint.X) * LineDirection.Y -
    (Point.Y - LinePoint.Y) * LineDirection.X;

  Result := Sqrt(Sqr(crossProduct.X) + Sqr(crossProduct.Y) +
    Sqr(crossProduct.Z));
end;

procedure TMainForm.DrawArrow(Canvas: TCanvas; x1, y1, x2, y2: Integer;
  ArrowSize: Integer);
var
  angle: double;
  dx, dy: Integer;
  x3, y3, x4, y4: Integer;
begin
  // Рисуем стрелку на конце линии
  dx := x2 - x1;
  dy := y2 - y1;
  angle := ArcTan2(dy, dx);

  // Левая часть стрелки
  x3 := Round(x2 - ArrowSize * Cos(angle + Pi / 6));
  y3 := Round(y2 - ArrowSize * Sin(angle + Pi / 6));

  // Правая часть стрелки
  x4 := Round(x2 - ArrowSize * Cos(angle - Pi / 6));
  y4 := Round(y2 - ArrowSize * Sin(angle - Pi / 6));

  Canvas.Polygon([Point(x2, y2), Point(x3, y3), Point(x4, y4)]);
end;

// -----------

procedure TMainForm.OnNewDepthFrame;
var
  imageFrame: NUI_IMAGE_FRAME;
  texture: INuiFrameTexture;
  lock: NUI_LOCKED_RECT;
  depth: pword;
  X, Y: Integer;
  w, h: cardinal;

  // Переменные для 3D
  depthValue: Word;
  depthInMeters: Single;
  worldX, worldY, worldZ: Single;
  screenX, screenY: Integer;
  prevPoint: TPoint;
  point3D: TPoint3D;
  scaleFactor: Single;
  rotationAngle: Single; // Угол поворота для вида сбоку
  colorIntensity: Byte;
  pointColor: TColor;
  a: Int64;

begin
  a := 0;

  if (FdepthStream = INVALID_HANDLE_VALUE) or
    failed(Fsensor.NuiImageStreamGetNextFrame(FdepthStream, 0, @imageFrame))
  then
    exit;

  NuiImageResolutionToSize(imageFrame.eResolution, w, h);

  try
    texture := imageFrame.pFrameTexture;
    if not assigned(texture) then
      exit;

    if failed(texture.LockRect(0, @lock, nil, 0)) then
      exit;
    try
      if cardinal(lock.Pitch) <> (2 * w) then
        exit;

      // Очищаем битмап
      Fbitmap.Canvas.Brush.Color := clBlack;
      Fbitmap.Canvas.FillRect(Rect(0, 0, Fbitmap.Width, Fbitmap.Height));

      // Настройки для 3D вида
      scaleFactor := TrackBar1.Position / 5; // Масштаб
      rotationAngle := TrackBar2.Position;
      // Угол поворота в градусах (90 - прямо сбоку, 45 - под углом)

      FMinDepth := TrackBar3.Position / 1.0; // если трекбар в сантиметрах
      FMaxDepth := (TrackBar4.Position * 2.0) / 1.0;

      SetLength(FDepthPoints, w * h);
      FDepthPointsCount := 0;

      // Устанавливаем перо для отрисовки
      Fbitmap.Canvas.Pen.Color := clWhite;
      Fbitmap.Canvas.Pen.Width := 1;

      depth := lock.pBits;
      prevPoint := Point(-1, -1);

      // Проходим по всем точкам глубины
      for Y := 0 to h - 1 do
      begin
        for X := 0 to w - 1 do
        begin

          depthValue := depth^ and not NUI_IMAGE_PLAYER_INDEX_MASK;

          // Пропускаем некорректные значения глубины
          if (depthValue = 0) or (depthValue = $FFFF) then
          begin
            inc(depth);
            continue;
          end;

          // Преобразуем значение глубины в метры
          depthInMeters :=
            (depthValue shr NUI_IMAGE_PLAYER_INDEX_SHIFT) / 100.0;

          if depthInMeters > 0 then
          begin

            // ОТРЕЗАЕМ ПО ГЛУБИНЕ
            if depthInMeters < FMinDepth then
            begin
              inc(depth);
              continue; // Слишком близко - пропускаем
            end;

            if depthInMeters > FMaxDepth then
            begin
              inc(depth);
              continue; // Слишком далеко - пропускаем
            end;

            // Если функция NuiImagePixelToDepth недоступна, используем приближение:
            worldX := -1 * (X - w / 2) * depthInMeters * 0.001;
            worldY := -1 * (Y - h / 2) * depthInMeters * 0.001;
            worldZ := depthInMeters;

            // Применяем 3D преобразование для вида сбоку
            // Поворот вокруг оси Y для вида сбоку
            point3D.X := worldZ * Cos(DegToRad(rotationAngle)) - worldX *
              Sin(DegToRad(rotationAngle));
            point3D.Y := worldY; // Вертикальная координата не меняется
            point3D.Z := worldZ * Sin(DegToRad(rotationAngle)) + worldX *
              Cos(DegToRad(rotationAngle));

            // Сохраняем точку в массиве
            FDepthPoints[FDepthPointsCount].X := point3D.X;
            FDepthPoints[FDepthPointsCount].Y := point3D.Y;
            FDepthPoints[FDepthPointsCount].Z := point3D.Z;
            inc(FDepthPointsCount);

            // Проекция на 2D экран (ортографическая проекция)
            screenX := Round(Fbitmap.Width / 2 + point3D.X * scaleFactor * 100);
            screenY := Round(Fbitmap.Height / 2 - point3D.Y *
              scaleFactor * 100);

            // Проверяем границы
            if (screenX >= 0) and (screenX < Fbitmap.Width) and (screenY >= 0)
              and (screenY < Fbitmap.Height) then
            begin

              if Hand3d.Checked then
                begin
                  colorIntensity := Round(255 * Y / h);
                  pointColor := RGB(colorIntensity, 255 - colorIntensity, 128);
                  Fbitmap.Canvas.Pixels[screenX, screenY] := pointColor;
                end;
              // Рисуем точку
              // Fbitmap.Canvas.Pixels[screenX, screenY] :=
              // GetDepthColor(depthValue); // Функция для цвета по глубине

              // Или рисуем линии между соседними точками
              { if prevPoint.X >= 0 then
                begin
                // Рисуем линию от предыдущей точки
                if Abs(screenX - prevPoint.X) < 50 then // Порог для избежания длинных линий
                begin
                colorIntensity := Round(255 * y / h);
                pointColor := RGB(colorIntensity, 255 - colorIntensity, 128);
                Fbitmap.Canvas.Pixels[screenX, screenY] := pointColor;
                end;
                end; }
              prevPoint := Point(screenX, screenY);
            end;
          end;

          inc(depth);
        end;
        prevPoint := Point(-1, -1); // Сбрасываем для новой строки
      end;

    finally
      texture.UnlockRect(0);
    end;

  finally
    Fsensor.NuiImageStreamReleaseFrame(FdepthStream, @imageFrame);
  end;

  Canvas.lock;
  try
    // UpdateBalls; // Обновляем позиции шариков
    // DrawBalls;   // Рисуем шарики
    SimpleHandDetection;
    // FastHandDetection2;
  //  SetCanvasZoomFactor(Fbitmap.Canvas, 200);
   // image3D.Canvas.Draw(0, 0, Fbitmap);
      image3D.Canvas.StretchDraw(image3D.ClientRect, FBitmap);

    // skeletonCanvas.Canvas.Draw(0, 0, Fbitmap);
    // Image1.Picture.Assign(Fbitmap);
    // skeletonCanvas.Canvas.StretchDraw ( Rect ( 0 , 0 , 1024 , 800 ) , Fbitmap ) ;

  finally
    Canvas.Unlock;
  end;

end;


procedure TMainForm.SetCanvasZoomFactor(Canvas: TCanvas; AZoomFactor: Integer);
var
  i: Integer;
begin
  if AZoomFactor = 100 then
    SetMapMode(Canvas.Handle, MM_TEXT)
  else
  begin
    SetMapMode(Canvas.Handle, MM_ISOTROPIC);
    SetWindowExtEx(Canvas.Handle, AZoomFactor, AZoomFactor, nil);
    SetViewportExtEx(Canvas.Handle, 100, 100, nil);
  end;
end;

procedure TMainForm.ButtonUpClick(Sender: TObject);
const
  NUI_CAMERA_ELEVATION_MINIMUM = -27; // Минимальный угол (градусы)
  NUI_CAMERA_ELEVATION_MAXIMUM = 27; // Максимальный угол (градусы)
begin
  if assigned(Fsensor) then
  begin
    inc(FTiltAngle, 5); // Шаг 5 градусов
    if Integer(FTiltAngle) > NUI_CAMERA_ELEVATION_MAXIMUM then
      Integer(FTiltAngle) := NUI_CAMERA_ELEVATION_MAXIMUM;

    Fsensor.NuiCameraElevationSetAngle(Integer(FTiltAngle));
  end;
end;

procedure TMainForm.ButtonDownClick(Sender: TObject);
const
  NUI_CAMERA_ELEVATION_MINIMUM = -27; // Минимальный угол (градусы)
  NUI_CAMERA_ELEVATION_MAXIMUM = 27; // Максимальный угол (градусы)
begin
  if assigned(Fsensor) then
  begin
    dec(FTiltAngle, 5); // Шаг 5 градусов
    if Integer(FTiltAngle) < NUI_CAMERA_ELEVATION_MINIMUM then
      Integer(FTiltAngle) := NUI_CAMERA_ELEVATION_MINIMUM;

    Fsensor.NuiCameraElevationSetAngle(Integer(FTiltAngle));
  end;
end;

procedure TMainForm.Button3Click(Sender: TObject);
begin
  Fcount := 0;
  cxLabel1.Caption := inttostr(Fcount);
end;

procedure TMainForm.Button4Click(Sender: TObject);
begin
  MainForm.Width := 656;
  MainForm.Height := 519+Panel3.Height + Panel2.Height + Panel1.Height;

  //ShowMessage(inttostr(image3D.Height) +'x'+ inttostr(image3D.Width));
end;

function TMainForm.openFirstSensor: Boolean;
var
  sensorEnum: INuiSensor;
  Count, i: Integer;
  w, h: cardinal;
  hr: HRESULT;
  streamHandle: THandle;
begin
  Result := False;
  Fsensor := nil;

  Uformat := NUI_IMAGE_RESOLUTION_640x480;

  if failed(NuiGetSensorCount(Count)) then
    exit;

  for i := 0 to Count - 1 do
  begin
    if failed(NuiCreateSensorByIndex(i, sensorEnum)) then
      continue;

    if sensorEnum.NuiStatus = S_OK then
    begin
      Fsensor := sensorEnum;
      Break;
    end;
  end;

  if not assigned(Fsensor) then
    exit;

  if failed(Fsensor.NuiInitialize(NUI_INITIALIZE_FLAG_USES_SKELETON or
    NUI_INITIALIZE_FLAG_USES_DEPTH_AND_PLAYER_INDEX)) then
    exit;

  FskeletonEvent := CreateEvent(nil, True, False, nil);
  FdepthEvent := CreateEvent(nil, True, False, nil);
  if (FskeletonEvent = 0) or (FdepthEvent = 0) then
  begin
    // Очистка созданных дескрипторов, если один из них не создался
    if FskeletonEvent <> 0 then
      CloseHandle(FskeletonEvent);
    if FdepthEvent <> 0 then
      CloseHandle(FdepthEvent);
    exit;
  end;

  // Включаем отслеживание скелета
  hr := Fsensor.NuiSkeletonTrackingEnable(FskeletonEvent,
    NUI_SKELETON_TRACKING_FLAG_ENABLE_SEATED_SUPPORT or
    NUI_SKELETON_TRACKING_FLAG_ENABLE_IN_NEAR_RANGE);
  if failed(hr) then
  begin
    CloseHandle(FskeletonEvent);
    CloseHandle(FdepthEvent);
    exit;
  end;

  FskeletonEvents := TEventDispatcherThread.createWith(Handle, FskeletonEvent);
  if not assigned(FskeletonEvents) then
  begin
    CloseHandle(FskeletonEvent);
    CloseHandle(FdepthEvent);
    exit;
  end;

  // Открываем поток глубины
  hr := Fsensor.NuiImageStreamOpen(NUI_IMAGE_TYPE_DEPTH_AND_PLAYER_INDEX,
    Uformat, 0, 2, FdepthEvent, streamHandle);

  if failed(hr) then
  begin
    CloseHandle(FskeletonEvent);
    CloseHandle(FdepthEvent);
    if assigned(FskeletonEvents) then
    begin
      FskeletonEvents.Terminate;
      FskeletonEvents.WaitFor;
      FreeAndNil(FskeletonEvents);
    end;
    exit;
  end;

  FdepthStream := streamHandle;

  // Устанавливаем флаги для потока глубины
  if failed(Fsensor.NuiImageStreamSetImageFrameFlags(FdepthStream,
    NUI_IMAGE_STREAM_FLAG_ENABLE_NEAR_MODE)) then
  begin
    OutputDebugString(PChar('NuiImageStreamSetImageFrameFlags failed: ' +
      inttostr(hr)));
  end;

  FdepthEvents := TEventDispatcherThread.createWith(Handle, FdepthEvent);
  if not assigned(FdepthEvents) then
  begin
    CloseHandle(FskeletonEvent);
    CloseHandle(FdepthEvent);
    if assigned(FskeletonEvents) then
    begin
      FskeletonEvents.Terminate;
      FskeletonEvents.WaitFor;
      FreeAndNil(FskeletonEvents);
    end;
    exit;
  end;

  // Получаем размер изображения
  NuiImageResolutionToSize(Uformat, w, h);

  // Создаем битмап для отображения
  Fbitmap := TBitmap.Create;
  try
    Fbitmap.Width := w;
    Fbitmap.Height := h;
    Fbitmap.PixelFormat := pf8bit;
  except
    FreeAndNil(Fbitmap);
    // Очистка ресурсов...
    exit;
  end;

  Result := True;
end;

function TMainForm.IsHandClosed(handPoints: TList<TPoint3D>; palmCenter: TPoint3D): Boolean;
var
  i: Integer;
  avgDistance, totalDistance: Single;
  distance: Single;
  maxDistance: Single;
  closedPointsCount: Integer;
begin
  Result := False;
  if handPoints.Count = 0 then Exit;

  totalDistance := 0;
  maxDistance := 0;
  closedPointsCount := 0;

  // Вычисляем среднее расстояние от точек руки до центра ладони
  for i := 0 to handPoints.Count - 1 do
  begin
    distance := Distance3D2(handPoints[i], palmCenter);
    totalDistance := totalDistance + distance;

    if distance > maxDistance then
      maxDistance := distance;

    // Считаем точки, которые близко к центру (возможно, пальцы сжаты)
    if distance < HAND_CLOSED_THRESHOLD then
      Inc(closedPointsCount);
  end;

  avgDistance := totalDistance / handPoints.Count;

  // Два условия для определения сжатой руки:
  // 1. Среднее расстояние небольшое (пальцы близко к центру)
  // 2. Большой процент точек находится близко к центру
  Result := (avgDistance < HAND_CLOSED_THRESHOLD * 1.5) and
            ((closedPointsCount / handPoints.Count) > 0.6);
end;

procedure TMainForm.OnGet(Sender: TObject; Count: integer);
var
  Buffer: array[0..255] of Byte;
  i: Integer;
  s: string;
begin
  if Count > SizeOf(Buffer) then
    Count := SizeOf(Buffer);

  Comm.Read(Buffer, Count);

  // Преобразуем байты в строку правильно
  s := '';
  for i := 0 to Count - 1 do
  begin
    // Пропускаем управляющие символы кроме CR/LF
    if (Buffer[i] >= 32) or (Buffer[i] = 13) or (Buffer[i] = 10) then
      s := s + Chr(Buffer[i]);
  end;

  shexStrFull := shexStrFull + s;
  step := step + Count;
end;

procedure TMainForm.CreateP(vport: string);
var
  s: string;
begin
  if Comm = nil then
  begin
    Comm := TComm.Create(nil);
    Comm.DeviceName := vport;
    Comm.BaudRate := getBaudRate(3); // 9600;
    Comm.Parity := getParity(0);
    Comm.Stopbits := getStopbits(0);
    Comm.Databits := getDatabits(4);
    Comm.FlowControl := fcDefault;
    Comm.OnRxChar := OnGet;
    try
      Comm.Open;
      isConnected := True;

    except
      on e: Exception do
      begin
        Comm.Close;
        Comm.Free;
        Comm := nil;
        isConnected := false;
      //  Showmessage(e.Message);
      end;
    end;
  end;

end;

procedure TMainForm.SendPalmCoordinatesToESP32(X, Y: Integer; IsClosed: Boolean);
var
  Command: array[0..15] of Byte;
  TouchState: Byte;
  ScreenWidth, ScreenHeight: Integer;
  HidX, HidY: Word;
begin
  // Проверяем соединение
  if (Comm = nil) or not isConnected then
    Exit;

  // Проверяем интервал отправки
 // if GetTickCount - FLastSendTime < FSendInterval then
 //   Exit;

 // FLastSendTime := GetTickCount;

  // Получаем текущий размер изображения
{  ScreenWidth := image3D.Width;
  ScreenHeight := image3D.Height;

  // Конвертируем координаты экрана в HID координаты (0-32767)
  if ScreenWidth > 0 then
    HidX := Word((X * 32767) div ScreenWidth)
  else
    HidX := 0;

  if ScreenHeight > 0 then
    HidY := Word((Y * 32767) div ScreenHeight)
  else
    HidY := 0;

  // Определяем состояние касания (0 = отпущено, 1 = нажато)

  }
  // Формируем команду для ESP32
  // Формат: 'T' X_LSB X_MSB Y_LSB Y_MSB STATE
  Command[0] := Ord(01);     // Команда Touch
  //Command[1] := Ord(0);     // Команда Touch

  if IsClosed then
    Command[1] := Ord(1)  // Рука сжата - имитируем касание
  else
    Command[1] := Ord(0); // Рука открыта - отпускаем

  Command[2] := x;//Ord(0);     // Команда Touch
 // if X>=0 then
 // Command[3] := x;//Ord(10);     // Команда Touch
 // else
  Command[3] := y;//Ord(10);     // Команда Touch
  Command[4] := Ord(0);     // Команда Touch
  Command[5] := Ord(0);     // Команда Touch
  Command[6] := Ord(0);     // Команда Touch


 // Command[1] := Lo(HidX);     // X LSB
 // Command[2] := Hi(HidX);     // X MSB
 // Command[3] := Lo(HidY);     // Y LSB
 // Command[4] := Hi(HidY);     // Y MSB
 // Command[5] := TouchState;   // Состояние (0/1)
 // Command[6] := Ord(#13);     // CR
 // Command[7] := Ord(#10);     // LF

  // Отправляем данные
  try
    Comm.Write(Command, 6);

    // Для отладки - выводим в консоль
   // OutputDebugString(PChar(Format('Sent: T %d %d %d', [X, Y, TouchState])));
  except
    on E: Exception do
      OutputDebugString(PChar('Send error: ' + E.Message));
  end;
end;

end.
