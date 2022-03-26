////////////////////////////////////////////////////////////////////////////////
//
//  ****************************************************************************
//  * Project   : SynEdit extended folding
//  * Unit Name : SynEasyPaintPlugin
//  * Purpose   : Плагин постобработки для отрисовки иконок и подсветки поиска
//  * Author    : Александр (Rouse_) Багель
//  * Copyright : © Fangorn Wizards Lab 1998 - 2022.
//  * Version   : 1.0
//  * Home Page : http://rouse.drkb.ru
//  * Home Blog : http://alexander-bagel.blogspot.ru
//  ****************************************************************************
//  * Latest Source  : https://github.com/AlexanderBagel/SynEdit
//  ****************************************************************************
//

unit SynEasyPaintPlugin;

interface

uses
  Windows,
  Classes,
  Graphics,
  ImgList,
  SynEdit,
  SynEditTypes,
  SynEasyHighlighter;

type
  TSynEasyPaintPlugin = class(TSynEditPlugin)
  private
    FSynEdit: TSynEdit;
    FImageList, FHeaderImageList: TCustomImageList;
    FHightLight: TSynEasyHighlighter;
    FSearchBoxColor, FSearchTextColor: TColor;
    function GetLineStartOffset(LineIndex: Integer): Integer;
  protected
    procedure AfterPaint(ACanvas: TCanvas; const AClip: TRect;
      FirstLine, LastLine: Integer); override;
  public
    constructor Create(ASynEdit: TSynEdit; AHightLight: TSynEasyHighlighter;
      AImageList, AHeaderImageList: TCustomImageList);
    property SearchBoxColor: TColor read FSearchBoxColor write FSearchBoxColor;
    property SearchTextColor: TColor read FSearchTextColor write FSearchTextColor;
  end;

implementation

type
  TSynEditFiendly = class(TSynEdit);

{ TSynEasyPaintPlugin }

procedure TSynEasyPaintPlugin.AfterPaint(ACanvas: TCanvas; const AClip: TRect;
  FirstLine, LastLine: Integer);
var
  LH, X, Y, FoldIndex: Integer;
  HeaderData: THeaderData;
  Marks: TGutterMarks;
  NeedPaintOnEditCanvas, IsHeader: Boolean;
  SearchText: string;
begin
  FirstLine := FSynEdit.RowToLine(FirstLine);
  LastLine := FSynEdit.RowToLine(LastLine);
  LH := FSynEdit.LineHeight;

  var OldFont := TFont.Create;
  try
    OldFont.Assign(ACanvas.Font);
    ACanvas.Brush.Color := SearchBoxColor;
    ACanvas.Brush.Style := bsSolid;

    if Assigned(FSynEdit.SearchEngine) then
      SearchText := FSynEdit.SearchEngine.Pattern
    else
      SearchText := '';


    while FirstLine <= LastLine do
    begin

      // пропускаем свернутые элементы
      if FSynEdit.AllFoldRanges.FoldHidesLine(FirstLine + 1) then
      begin
        Inc(FirstLine);
        Continue;
      end;

      // отрисовка результатов поиска
      if SearchText <> '' then
      begin
        var Count := FSynEdit.SearchEngine.FindAll(
          FSynEdit.Lines[FirstLine - 1]);
        for var ItemIndex := 0 to Count - 1 do
        begin
          var CurrCoord := BufferCoord(
            FSynEdit.SearchEngine.Results[ItemIndex], FirstLine);
          if CurrCoord = FSynEdit.BlockBegin then
            Continue;
          var SearchResultText := Copy(FSynEdit.Lines[FirstLine - 1],
            FSynEdit.SearchEngine.Results[ItemIndex],
            FSynEdit.SearchEngine.Lengths[ItemIndex]);
          var Pt := FSynEdit.RowColumnToPixels(
            FSynEdit.BufferToDisplayPos(CurrCoord));
          var Rct := Rect(Pt.X, Pt.Y, Pt.X +
            FSynEdit.CharWidth * Length(SearchResultText),
            Pt.Y + FSynEdit.LineHeight);
          ACanvas.FillRect(Rct);
          ACanvas.Font.Color := SearchTextColor;
          ACanvas.TextRect(Rct, Pt.X, Pt.Y, SearchResultText);
        end;
      end;

      // смотрим, линия является заголовком?
      IsHeader := FHightLight.GetIsHeader(FirstLine, HeaderData);

      // смотрим есть ли маркер на позиции?
      if not IsHeader then
        if not FHightLight.GetGutterMark(FirstLine, Marks) then
        begin
          Inc(FirstLine);
          Continue;
        end;

      Y := (LH - FImageList.Height) div 2 +
        LH * (FSynEdit.LineToRow(FirstLine) - FSynEdit.TopLine + 1);

      // отрисовка маркеров файлов/папок и прочего
      // все что рисуется в области SynEdit правее Gutter

      X := GetLineStartOffset(FirstLine);

      NeedPaintOnEditCanvas := IsHeader;
      if X > TSynEditFiendly(FSynEdit).FGutterWidth then
        NeedPaintOnEditCanvas := True;

      if NeedPaintOnEditCanvas then
      begin
        if IsHeader then
        begin
          X := FSynEdit.CharWidth + 8 +
            TSynEditFiendly(FSynEdit).TextOffset;
          FHeaderImageList.Draw(ACanvas,
            X + HeaderData.XOffset,
            Y + HeaderData.YOffset,
            HeaderData.ImageIndex);
          Inc(FirstLine);
          Continue;
        end
        else
        begin
          if Marks.InEditImageIndex >= 0 then
            FImageList.Draw(ACanvas, X, Y, Marks.InEditImageIndex);
        end;
      end;

      // отрисовка в рамках гуттера
      X := 1;
      if Marks.FirstImageIndex >= 0 then
        FImageList.Draw(ACanvas, X, Y, Marks.FirstImageIndex);
      Inc(X, FImageList.Width);
      if Marks.SecondImageIndex >= 0 then
        FImageList.Draw(ACanvas, X, Y, Marks.SecondImageIndex);

      Inc(FirstLine);
    end;

    ACanvas.Font.Assign(OldFont);
  finally
    OldFont.Free;
  end;
end;

constructor TSynEasyPaintPlugin.Create(ASynEdit: TSynEdit;
  AHightLight: TSynEasyHighlighter; AImageList,
  AHeaderImageList: TCustomImageList);
begin
  inherited Create(ASynEdit);
  FSynEdit := ASynEdit;
  FImageList := AImageList;
  FHeaderImageList := AHeaderImageList;
  FHightLight := AHightLight;
  FSearchBoxColor := RGB(73, 99, 188);
  FSearchTextColor := clWhite;
end;

function TSynEasyPaintPlugin.GetLineStartOffset(LineIndex: Integer): Integer;
var
  SpaceCount: Integer;
  p: PWideChar;
begin
  p := PWideChar(UnicodeString(FSynEdit.Lines[LineIndex]));
  SpaceCount := 0;
  if Assigned(p) then
  begin
    while (p^ >= #1) and (p^ <= #32) do
    begin
      if p^ = #9 then
        Inc(SpaceCount, FSynEdit.TabWidth)
      else
        Inc(SpaceCount);
      Inc(p);
    end;
  end;
  Result := SpaceCount * FSynEdit.CharWidth +
    TSynEditFiendly(FSynEdit).TextOffset - 4 - FImageList.Width;
end;

end.
