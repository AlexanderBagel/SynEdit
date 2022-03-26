////////////////////////////////////////////////////////////////////////////////
//
//  ****************************************************************************
//  * Project   : SynEdit extended folding
//  * Unit Name : SynEasyHighlighter
//  * Purpose   : Хайлайтер для SynEdit обеспечивающий легкое управление
//  *           : по аналогу с RichEdit
//  * Author    : Александр (Rouse_) Багель
//  * Copyright : © Fangorn Wizards Lab 1998 - 2022.
//  * Version   : 1.0
//  * Home Page : http://rouse.drkb.ru
//  * Home Blog : http://alexander-bagel.blogspot.ru
//  ****************************************************************************
//  * Latest Source  : https://github.com/AlexanderBagel/SynEdit
//  ****************************************************************************
//

unit SynEasyHighlighter;

interface

uses
  Windows,
  Classes,
  Graphics,
  SysUtils,
  Controls,
  ShellAPI,
  Types,
  Generics.Defaults,
  Generics.Collections,
  SynEdit,
  SynEditTypes,
  SynEditHighlighter,
  SynEditCodeFolding,
  SynEditMiscClasses;

type
  // номера иконок отображаемых в гуттере
  TGutterMarks = record
    FirstImageIndex, SecondImageIndex, InEditImageIndex: Integer;
  end;

  THeaderData = record
    ImageIndex, XOffset, YOffset: Integer;
    BackgroundColor, ForegroundColor: TColor;
  end;

  TUrlClickEvent = procedure(Sender: TObject; LineIndex: Integer;
    const URL: string; var Handled: Boolean) of object;

  TSynEasyHighlighter = class(TSynCustomCodeFoldingHighlighter)
  private type
    TColorKey = record
      LineIndex, SelStart: Integer
    end;
    TColorData = record
      LineIndex, SelStart, SelEnd: Integer;
      TokenAttribute: TSynHighlighterAttributes;
    end;
    TFoldingKey = record
      LineIndex,
      DataIndex: Integer; // -1 будет возвращать только кол-во элементов в строке
    end;
    TFoldingData = record
      Start, Collapsed: Boolean;
      case Integer of
        0: (FoldID: Integer);
        1: (Count: Integer);
    end;
  private const
    NoToken = nil;
    DefaultAttributeName = '_default';
    UrlAttributeName = '_url';
  private
    FEdit: TSynEdit;
    FDefaultTextAttributes: TSynHighlighterAttributes;
    FURLAttributes: TSynHighlighterAttributes;
    FTokenAttribute: TSynHighlighterAttributes;
    FColors: TDictionary<TColorKey, TColorData>;
    FHeaders: TDictionary<Integer, THeaderData>;
    FFolding: TDictionary<TFoldingKey, TFoldingData>;
    FGutterMarks: TDictionary<Integer, TGutterMarks>;
    FColorsChecked: Boolean;
    FEnableCheckColors: Boolean;
    FMouseDown: TPoint;
    FUpdateCount: Integer;
    FUrlClick: TUrlClickEvent;
    procedure CaretReturnProc;
    procedure CheckColorInterceptions;
    procedure IdentProc;
    procedure LineFeedProc;
    procedure RecreateFolderRange(FromLine, ToLine: Integer);
  private
    // внутренние обработчики SynEdit необходимые для работы с URL
    procedure SynEditorSpecialLineColors(Sender: TObject; Line: Integer;
      var Special: Boolean; var FG, BG: TColor);
    procedure OnEditMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure OnEditMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure OnEditMouseCursor(Sender: TObject; const aLineCharPos: TBufferCoord;
      var aCursor: TCursor);
  public
    // перекрытые методы необходимые для работы хайлайтера
    constructor Create(AOwner: TComponent; ASynEdit: TSynEdit); reintroduce; virtual;
    destructor Destroy; override;
    procedure CorrectFoldShapeRect(LineIndex: Integer; var ARect: TRect); override;
    function GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes; override;
    function GetEol: Boolean; override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: Integer; override;
    procedure Next; override;
    procedure ScanForFoldRanges(FoldRanges: TSynFoldRanges;
      LinesToScan: TStrings; FromLine: Integer; ToLine: Integer); override;
  public

    //
    // =========================================================================
    // дополнительные методы с которыми программист работает из внешнего кода
    // =========================================================================
    //

    /// <summary>
    ///  Подсвечивает тест в выбраной линии SynEdit
    ///  LineIndex: номер строки
    ///  SelStart: начало выделения
    ///  SelLength: длина выделения
    ///  ForegroundColor: цвет текста
    ///  BackgroundColor: цвет фона
    ///  FontStyle: стиль шрифта
    /// </summary>
    procedure AddSelection(LineIndex, SelStart, SelLength: Integer;
      ForegroundColor, BackgroundColor: TColor; const FontStyle: TFontStyles);

    /// <summary>
    ///  Добавляет для строки экспандер
    ///  LineIndex: номер строки
    ///  FoldID: уникальный номер для сворачиваемой группы
    ///  Start: первая или последняя строка в группе фолдинга
    ///  Collapsed: состояние строки (свернута/развернута)
    /// </summary>
    procedure AddFolding(LineIndex, FoldID: Integer; Start: Boolean;
      Collapsed: Boolean = True);

    /// <summary>
    ///  Добавляет одну или две иконки, которые будут отрисованы в гутере
    ///  Отрисовкой занимается TSynEasyPaintPlugin в постобработке
    ///  LineIndex: номер строки
    ///  Marks: данные по иконкам
    /// </summary>
    procedure AddGutterMark(LineIndex: Integer; const Marks: TGutterMarks);

    /// <summary>
    ///  Указаная линия отображается как заголовок.
    ///  Постобработка заголовков проиходит в плагине TSynEasyPaintPlugin
    ///  LineIndex: номер строки
    ///  Data: параметры отрисовки заголовка, где:
    ///    Data.ImageIndex - номер иконки из TSynEasyPaintPlugin.HeaderImageList
    ///    Data.XOffset - смещение по оси Х для более точной донастройки
    ///    Data.YOffset - смещение по оси Y
    ///    Data.ForegroundColor: цвет текста
    ///    Data.BackgroundColor: цвет фона
    /// </summary>
    procedure AddHeader(LineIndex: Integer; const Data: THeaderData);

    /// <summary>
    ///  Помеченый текст будет работать как гиперссылка.
    ///  При клике на него вызовется обработчик OnUrlClick
    ///  LineIndex: номер строки
    ///  SelStart: начало выделения
    ///  SelLength: длина выделения
    /// </summary>
    procedure AddURL(LineIndex, SelStart, SelLength: Integer);

    procedure BeginUpdate;
    procedure Clear;
    procedure EndUpdate;

    //
    // =========================================================================
    // Служебные функции необходимые для работы TSynEasyPaintPlugin
    // =========================================================================
    //

    function GetIsHeader(LineIndex: Integer; out HeaderData: THeaderData): Boolean;
    function GetGutterMark(LineIndex: Integer; out Marks: TGutterMarks): Boolean;

  published
    /// <summary>
    ///  Включает контроль подсветки чтобы она не заползада друг на друга.
    ///  Замедляет работу класса.
    /// </summary>
    property EnableCheckColorInterceptions: Boolean read FEnableCheckColors write FEnableCheckColors default False;
    property DefaultTextAttributes: TSynHighlighterAttributes read FDefaultTextAttributes;
    property OnUrlClick: TUrlClickEvent read FUrlClick write FUrlClick;
  end;

implementation

type
  TSynEditFiendly = class(TSynEdit);

{ TSynEasyHighlighter }

procedure TSynEasyHighlighter.AddFolding(LineIndex, FoldID: Integer; Start,
  Collapsed: Boolean);
var
  Key: TFoldingKey;
  Data: TFoldingData;
  Count: Integer;
begin
  Count := 0;

  // сначала смотрим, сколько записей у нас об этой строке
  Key.LineIndex := LineIndex + 1;
  Key.DataIndex := -1;
  if FFolding.TryGetValue(Key, Data) then
    Count := Data.Count;

  // инициализируем новый ключ
  Key.DataIndex := Count;

  // заполняем параметры
  Data.FoldID := FoldID;
  Data.Start := Start;
  Data.Collapsed := Collapsed;
  FFolding.AddOrSetValue(Key, Data);

  // обновляем информаию о количестве записей
  Inc(Count);
  Data.Count := Count;
  Key.DataIndex := -1;
  FFolding.AddOrSetValue(Key, Data);
end;

procedure TSynEasyHighlighter.AddGutterMark(LineIndex: Integer;
  const Marks: TGutterMarks);
begin
  FGutterMarks.AddOrSetValue(LineIndex, Marks);
end;

procedure TSynEasyHighlighter.AddHeader(LineIndex: Integer;
  const Data: THeaderData);
begin
  FHeaders.AddOrSetValue(LineIndex + 1, Data);
end;

procedure TSynEasyHighlighter.AddSelection(LineIndex, SelStart,
  SelLength: Integer; ForegroundColor, BackgroundColor: TColor;
  const FontStyle: TFontStyles);

  function MakeAttributeName: string;
  begin
    Result := IntToHex(BackgroundColor, 8) + IntToHex(ForegroundColor, 8);
    if fsBold in FontStyle then
      Result := Result + 'B';
    if fsItalic in FontStyle then
      Result := Result + 'I';
    if fsUnderline in FontStyle then
      Result := Result + 'U';
    if fsStrikeOut in FontStyle then
      Result := Result + 'S';
  end;

var
  AttrName: string;
  I: Integer;
  Data: TColorData;
  Key: TColorKey;
begin
  if SelLength <= 0 then Exit;

  // инициализируем параметры расцветки
  FColorsChecked := False;
  Data.LineIndex := LineIndex;
  Data.SelStart := SelStart;
  Data.SelEnd := SelStart + SelLength;
  Data.TokenAttribute := nil;

  // Ищем похожий атрибут
  AttrName := MakeAttributeName;
  for I := 0 to AttrCount - 1 do
    if Attribute[I].Name = AttrName then
    begin
      Data.TokenAttribute := Attribute[I];
      Break;
    end;

  // Если не нашли - создаем и добавляем в коллекцию
  if Data.TokenAttribute = nil then
  begin
    Data.TokenAttribute := TSynHighlighterAttributes.Create(AttrName);
    Data.TokenAttribute.Background := BackgroundColor;
    Data.TokenAttribute.Foreground := ForegroundColor;
    Data.TokenAttribute.Style := FontStyle;
    AddAttribute(Data.TokenAttribute);
  end;

  // добавляем координаты с которых будет идти посветка атрибутом
  Key.LineIndex := Data.LineIndex;
  Key.SelStart := Data.SelStart;
  FColors.AddOrSetValue(Key, Data);
end;

procedure TSynEasyHighlighter.AddURL(LineIndex, SelStart, SelLength: Integer);
var
  Data: TColorData;
  Key: TColorKey;
begin
  Data.LineIndex := LineIndex;
  Data.SelStart := SelStart;
  Data.SelEnd := SelStart + SelLength;
  Data.TokenAttribute := FURLAttributes;
  Key.LineIndex := Data.LineIndex;
  Key.SelStart := Data.SelStart;
  FColors.AddOrSetValue(Key, Data);
end;

procedure TSynEasyHighlighter.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

constructor TSynEasyHighlighter.Create(AOwner: TComponent; ASynEdit: TSynEdit);
begin
  inherited Create(AOwner);

  FDefaultTextAttributes := TSynHighlighterAttributes.Create(DefaultAttributeName);
  FURLAttributes := TSynHighlighterAttributes.Create(UrlAttributeName);
  FURLAttributes.Foreground := clNavy;

  FColors := TDictionary<TColorKey, TColorData>.Create;
  FHeaders := TDictionary<Integer, THeaderData>.Create;
  FFolding := TDictionary<TFoldingKey, TFoldingData>.Create;
  FGutterMarks := TDictionary<Integer, TGutterMarks>.Create;

  FEdit := ASynEdit;
  FEdit.RightEdge := 0;
  FEdit.Gutter.Width := 38;
  FEdit.Highlighter := Self;
  FEdit.UseCodeFolding := True;
  FEdit.CodeFolding.ShowCollapsedLine := False;
  FEdit.CodeFolding.CollapsedLineColor := $B09684;
  FEdit.CodeFolding.FolderBarLinesColor := $CC9999;
  FEdit.Gutter.Color := clWindow;
  FEdit.Gutter.BorderColor := $B09684;
  FEdit.Gutter.BorderStyle := gbsRight;
  FEdit.OnSpecialLineColors := SynEditorSpecialLineColors;
  FEdit.AddMouseDownHandler(OnEditMouseDown);
  FEdit.AddMouseUpHandler(OnEditMouseUp);
  FEdit.AddMouseCursorHandler(OnEditMouseCursor);
  FEdit.Options := FEdit.Options - [eoShowScrollHint] + [eoNoCaret];

  // отключаем отрисовку разделителей пробелов слева
  FEdit.CodeFolding.IndentGuides := False;
end;

procedure TSynEasyHighlighter.CaretReturnProc;
begin
  FTokenAttribute := NoToken;
  Inc(Run);
  if FLine[Run] = #10 then
    Inc(Run);
end;

procedure TSynEasyHighlighter.CheckColorInterceptions;
var
  I: Integer;
  NeedUpdate: Boolean;
  ColorEnumerator: TEnumerator<TColorKey>;
  ColorKeys: TList<TColorKey>;
  ColorsData: array of TColorData;
begin
  // проверка подсветки чтобы не было пересечений

  if not EnableCheckColorInterceptions then
  begin
    FColorsChecked := True;
    Exit;
  end;

  if FUpdateCount > 0 then Exit;

  if not FColorsChecked then
  begin
    FColorsChecked := True;

    ColorKeys := TList<TColorKey>.Create(
      TComparer<TColorKey>.Construct(
        function (const A, B: TColorKey): Integer
        begin
          Result := A.LineIndex - B.LineIndex;
          if Result = 0 then
            Result := A.SelStart - B.SelStart;
        end)
    );
    try
      // этап первый, получаем все ключи словаря
      ColorEnumerator := FColors.Keys.GetEnumerator;
      try
        while ColorEnumerator.MoveNext do
          ColorKeys.Add(ColorEnumerator.Current);
      finally
        ColorEnumerator.Free;
      end;

      // они нам нужны в сортированом виде
      ColorKeys.Sort;

      // теперь вытаскиваем данные отсортированные по ключу
      SetLength(ColorsData, ColorKeys.Count);
      for I := 0 to ColorKeys.Count - 1 do
        FColors.TryGetValue(ColorKeys.List[I], ColorsData[I]);

      // ищем пересечения
      NeedUpdate := False;
      for I := 1 to FColors.Count - 1 do
        begin
          if ColorsData[I - 1].LineIndex <> ColorsData[I].LineIndex then
            Continue;
          if ColorsData[I - 1].SelEnd > ColorsData[I].SelStart then
          begin
            NeedUpdate := True;
            ColorsData[I - 1].SelEnd := ColorsData[I].SelStart;
          end;
        end;

      // и закидываем актуальные данные обратно в словарь
      if NeedUpdate then
      begin
        FColors.Clear;
        for I := 0 to ColorKeys.Count - 1 do
          FColors.AddOrSetValue(ColorKeys.List[I], ColorsData[I]);
      end;

    finally
      ColorKeys.Free;
    end;

  end;
end;

procedure TSynEasyHighlighter.Clear;
begin
  BeginUpdate;
  try
    FColors.Clear;
    FHeaders.Clear;
    FFolding.Clear;
    FGutterMarks.Clear;
    FreeHighlighterAttributes;
  finally
    EndUpdate;
  end;
end;

procedure TSynEasyHighlighter.CorrectFoldShapeRect(LineIndex: Integer;
  var ARect: TRect);
var
  Mark: TGutterMarks;
begin
  inherited;
  // если элемент отрисовывается с иконкой, то нужно подвинуть экспандер левее
  if FGutterMarks.TryGetValue(LineIndex, Mark) and (Mark.InEditImageIndex >= 0) then
    OffsetRect(ARect, -16, 0);
end;

destructor TSynEasyHighlighter.Destroy;
begin
  FEdit.RemoveMouseDownHandler(OnEditMouseDown);
  FEdit.RemoveMouseUpHandler(OnEditMouseUp);
  FEdit.RemoveMouseCursorHandler(OnEditMouseCursor);
  FGutterMarks.Free;
  FDefaultTextAttributes.Free;
  FURLAttributes.Free;
  FFolding.Free;
  FColors.Free;
  FHeaders.Free;
  inherited;
end;

procedure TSynEasyHighlighter.EndUpdate;
var
  I, A: Integer;
  Key: TFoldingKey;
  Data: TFoldingData;
  HaseCollapsed: Boolean;
begin
  Dec(FUpdateCount);
  if FUpdateCount = 0 then
  begin
    CheckColorInterceptions;
    RecreateFolderRange(0, FEdit.Lines.Count);

    // Сворачиваем нужные фолды
    HaseCollapsed := False;
    for I := 0 to FEdit.AllFoldRanges.Count - 1 do
    begin
      Key.LineIndex := FEdit.AllFoldRanges[I].FromLine;
      Key.DataIndex := -1;
      if FFolding.TryGetValue(Key, Data) then
        for A := 0 to Data.Count - 1 do
        begin
          Key.DataIndex := A;
          if FFolding.TryGetValue(Key, Data) and Data.Start and Data.Collapsed then
          begin
            FEdit.Collapse(I, False);
            HaseCollapsed := True;
          end;
        end;
    end;
    // если было свертывание - инвалидируем SynEdit
    if HaseCollapsed then
    begin
      FEdit.InvalidateLines(-1, -1);
      FEdit.InvalidateGutterLines(-1, -1);
      FEdit.EnsureCursorPosVisible;
    end;
  end;
end;

function TSynEasyHighlighter.GetDefaultAttribute(
  Index: Integer): TSynHighlighterAttributes;
begin
  Result := FDefaultTextAttributes;
end;

function TSynEasyHighlighter.GetEol: Boolean;
begin
  Result := Run = FLineLen + 1;
end;

function TSynEasyHighlighter.GetGutterMark(LineIndex: Integer;
  out Marks: TGutterMarks): Boolean;
begin
  Result := FGutterMarks.TryGetValue(LineIndex, Marks);
end;

function TSynEasyHighlighter.GetIsHeader(LineIndex: Integer;
  out HeaderData: THeaderData): Boolean;
begin
  Result := FHeaders.TryGetValue(LineIndex, HeaderData);
end;

function TSynEasyHighlighter.GetTokenAttribute: TSynHighlighterAttributes;
begin
  Result := FTokenAttribute;
  if Result = nil then
    Result := FDefaultTextAttributes;
end;

function TSynEasyHighlighter.GetTokenKind: Integer;
begin
  Result := Integer(FTokenAttribute);
end;

procedure TSynEasyHighlighter.IdentProc;
var
  Key: TColorKey;
  Data: TColorData;
begin
  CheckColorInterceptions;
  Key.LineIndex := FLineNumber;
  Key.SelStart := Run;
  if FColors.TryGetValue(Key, Data) then
  begin
    FTokenAttribute := Data.TokenAttribute;
    Run := Data.SelEnd;
    if Run > FLineLen then
      Run := FLineLen + 1; // обязательно + 1 иначе не бдет выхода по GetEol
  end
  else
  begin
    FTokenAttribute := NoToken;
    Inc(Run);
  end;
end;

procedure TSynEasyHighlighter.LineFeedProc;
begin
  FTokenAttribute := NoToken;
  Inc(Run);
end;

procedure TSynEasyHighlighter.Next;
begin
  FTokenPos := Run;
  case fLine[Run] of
    #10: LineFeedProc;
    #13: CaretReturnProc;
  else
    IdentProc;
  end;
  inherited;
end;

procedure TSynEasyHighlighter.OnEditMouseCursor(Sender: TObject;
  const aLineCharPos: TBufferCoord; var aCursor: TCursor);
var
  TokenType, Start: Integer;
  Token: UnicodeString;
  Attri: TSynHighlighterAttributes;
begin
  FEdit.GetHighlighterAttriAtRowColEx(aLineCharPos, Token, TokenType, Start, Attri);
  if Attri = FURLAttributes then
    aCursor := crHandPoint;
end;

procedure TSynEasyHighlighter.OnEditMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
    FMouseDown := Point(X, Y);
end;

procedure TSynEasyHighlighter.OnEditMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  ptLineCol: TBufferCoord;
  TokenType, Start: Integer;
  Token: UnicodeString;
  Attri: TSynHighlighterAttributes;
  Handled: Boolean;
begin
  if Button = mbLeft then
  begin
    if (Abs(FMouseDown.X - X) > 4) or (Abs(FMouseDown.Y - Y) > 4) then
      Exit;

    ptLineCol := FEdit.DisplayToBufferPos(FEdit.PixelsToRowColumn(X,Y));

    FEdit.GetHighlighterAttriAtRowColEx(ptLineCol, Token, TokenType, Start, Attri);
    if Attri = FURLAttributes then
    begin
      Handled := False;
      if Assigned(FUrlClick) then
        FUrlClick(FEdit, ptLineCol.Line, Token, Handled);
      if not Handled then
        ShellExecute(0, 'open', PChar(Token), nil, nil, SW_SHOWNORMAL);
    end;
  end;
end;

procedure TSynEasyHighlighter.RecreateFolderRange(FromLine, ToLine: Integer);
var
  I, A: Integer;
  Key: TFoldingKey;
  Data: TFoldingData;
begin
  FEdit.AllFoldRanges.StartScanning;
  try
    for I := FromLine to ToLine do
    begin
      // узнаем количество записей о строке
      Key.LineIndex := I;
      Key.DataIndex := -1;
      if FFolding.TryGetValue(Key, Data) then
      begin
        for A := 0 to Data.Count - 1 do
        begin
          Key.DataIndex := A;
          if FFolding.TryGetValue(Key, Data) then
          begin
            // выставляем реальное состояние фолдинга у редактора
            if Data.Start then
              FEdit.AllFoldRanges.StartFoldRange(I, Data.FoldID)
            else
              FEdit.AllFoldRanges.StopFoldRange(I, Data.FoldID);
          end;
        end;
      end
      else
        FEdit.AllFoldRanges.NoFoldInfo(I);
    end;
  finally
    FEdit.AllFoldRanges.StopScanning(FEdit.Lines);
  end;
  FEdit.InvalidateGutter;
end;

procedure TSynEasyHighlighter.ScanForFoldRanges(FoldRanges: TSynFoldRanges;
  LinesToScan: TStrings; FromLine, ToLine: Integer);
begin
  RecreateFolderRange(FromLine, ToLine);
end;

procedure TSynEasyHighlighter.SynEditorSpecialLineColors(Sender: TObject;
  Line: Integer; var Special: Boolean; var FG, BG: TColor);
var
  Data: THeaderData;
begin
  Special := FHeaders.TryGetValue(Line, Data);
  if Special then
  begin
    BG := Data.BackGroundColor;
    FG := Data.ForeGroundColor;
  end;
end;

end.
