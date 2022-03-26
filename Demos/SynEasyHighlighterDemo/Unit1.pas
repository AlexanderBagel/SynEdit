unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  System.ImageList, Vcl.ImgList,

  SynEdit,
  SynEasyHighlighter,
  SynEasyPaintPlugin, SynEditMiscClasses, SynEditSearch;

type
  TForm1 = class(TForm)
    SynEdit1: TSynEdit;
    il16: TImageList;
    il32: TImageList;
    SynEditSearch1: TSynEditSearch;
    procedure FormCreate(Sender: TObject);
  private
    FHighLighter: TSynEasyHighlighter;
    procedure OnUrlClick(Sender: TObject; LineIndex: Integer;
      const URL: string; var Handled: Boolean);
  public
    procedure InitEditText;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  // инициализируем хайлайтер
  FHighLighter := TSynEasyHighlighter.Create(Self, SynEdit1);

  // включаем отрисовку разделителей перед текстом, а не на Gutter
  {$IFDEF SYN_CodeFolding2}
  // ВНИМАНИЕ!!!
  // проект должен быть собран с директивой SYN_CodeFolding2
  SynEdit1.DrawFoldingMarkBeforeLine := True;

  // включаем отображиние количества пропущеных строк
  SynEdit1.ShowSkippedLineCountHint := True;
  {$ENDIF}

  // назначаем хайлайтер SynEdit-у
  SynEdit1.Highlighter := FHighLighter;

  // инициализируем плагин постобработки
  TSynEasyPaintPlugin.Create(SynEdit1, FHighLighter, il16, il32);

  // заполненяем SynEdit данными с подсветкой.
  InitEditText;
end;

procedure TForm1.InitEditText;
const
  QuarterSpace = '    ';

  function Add(const Caption1, Description1, Caption2, Description2: string;
    CaptionColor: TColor; DescriptionColor: TColor): Integer; overload;
  begin
    Result := SynEdit1.Lines.Add(
      Caption1 + Description1 + Caption2 + Description2);
    // подсветка кэпшена если назначен цвет
    if CaptionColor <> clNone then
    begin
      // первого
      FHighLighter.AddSelection(
        Result, 0, Length(Caption1), CaptionColor, clNone, []);
      // и второго
      if Caption2 <> EmptyStr then
        FHighLighter.AddSelection(
          Result, Length(Caption1 + Description1),
          Length(Caption2), CaptionColor, clNone, []);
    end;
    // и дескрипшена
    FHighLighter.AddSelection(
      Result, Length(Caption1), Length(Description1),
      DescriptionColor, clNone, []);
    // вместе со вторым
    if Description2 <> EmptyStr then
      FHighLighter.AddSelection(
        Result, Length(Caption1 + Description1 + Caption2),
        Length(Description2), DescriptionColor, clNone, []);
  end;

  function Add(const Caption, Description: string;
    CaptionColor, DescriptionColor: TColor): Integer; overload;
  begin
    Result := Add(Caption, Description,
      EmptyStr, EmptyStr, CaptionColor, DescriptionColor);
  end;

  function Add(const Caption, Description: string;
    DescriptionColor: TColor): Integer; overload;
  begin
    Result := Add(Caption, Description,
      EmptyStr, EmptyStr, clNone, DescriptionColor);
  end;

  procedure AddHeader(const Caption: string; ImageIndex: Integer);
  var
    LineNumber: Integer;
    Header: THeaderData;
  begin
    LineNumber := SynEdit1.Lines.Add(Caption);
    // нстройка заголовка происходит через назначение иконки и её координат
    Header.ImageIndex := ImageIndex;
    Header.XOffset := -16;
    Header.YOffset := -28;
    // а также выставлением цветов
    Header.BackgroundColor := RGB(132, 150, 176);
    Header.ForegroundColor := clWhite;
    FHighLighter.AddHeader(LineNumber, Header);
  end;

  procedure AddCharsWithRandomColors;
  const
    Caption = 'Можно раскрасить любым цветом ';
    Description = 'любой символ строки';
  var
    LineNumber, I: Integer;
  begin
    LineNumber := SynEdit1.Lines.Add(Caption + Description);
    for I := 1 to Length(Description) do
      FHighLighter.AddSelection(
        LineNumber, Length(Caption) + I, 1, TColor(Random(MaxInt) and $FFFFFF), clNone, []);
  end;

  procedure AddUrl(const Caption, Description: string);
  var
    LineNumber: Integer;
  begin
    LineNumber := SynEdit1.Lines.Add(Caption + Description);
    // вся обработка работы с URL сидит в хайлайтере, вызов простой
    FHighLighter.AddURL(
      LineNumber, Length(Caption), Length(Description));
    // можем назначить обработчик клика по ссылке
    FHighLighter.OnUrlClick := OnUrlClick;
  end;

  procedure AddGutterIcon;
  var
    LineNumber: Integer;
    Icons: TGutterMarks;
  begin
    LineNumber := SynEdit1.Lines.Add('У линий можно назначать иконку, рисуемую в Gutter-е');
    Icons.FirstImageIndex := 0;     // первая иконка
    Icons.SecondImageIndex := -1;   // вторая иконка
    Icons.InEditImageIndex := -1;   // иконка рисуемая в области редактора левее текста
    FHighLighter.AddGutterMark(LineNumber, Icons);

    LineNumber := SynEdit1.Lines.Add('Или, при желании, даже две');
    Icons.FirstImageIndex := 0;
    Icons.SecondImageIndex := 1;
    Icons.InEditImageIndex := -1;
    FHighLighter.AddGutterMark(LineNumber, Icons);
  end;

  procedure AddSearchedText;
  begin
    SynEdit1.Lines.Add('В этом тексте будет искаться слово "пример"');
    SynEdit1.Lines.Add('Например слово слева будет подсвечено, примерно с третьей буквы.');
    SynEdit1.SearchReplace('пример', EmptyStr, []);
  end;

  procedure AddSimpleFoldingData;
  const
    Bulite = #$2022 + #32;
    CaptionColor = $96542F;
    ValueColor = $B09684;
  var
    FirstLineIndex, LineIndex, FoldID: Integer;
  begin
    FoldID := 0;
    SynEdit1.Lines.Add('Установленные сетевые интерфейсы:');

    // данные первой группы ====================================================

    FirstLineIndex := Add(QuarterSpace + Bulite + 'Адаптер: ',
      'Intel(R) Ethernet Connection (7) I219-V', CaptionColor, ValueColor);

    // сворачиваем с этой линии
    FHighLighter.AddFolding(FirstLineIndex, FoldID, True,
      True // группа свернута
      );

    Add(QuarterSpace + Bulite + 'Тип адаптера: ', 'MIB_IF_TYPE_ETHERNET',
      CaptionColor, ValueColor);
    Add(QuarterSpace + Bulite + 'Используемые IP адреса: ',  EmptyStr,
      CaptionColor, clNone);
    LineIndex := Add(QuarterSpace + QuarterSpace + 'IP: ',
      '192.168.1.1', ', маска подсети: ', '255.255.255.0',
      CaptionColor, ValueColor);

    // и по вот эту
    FHighLighter.AddFolding(LineIndex, FoldID, False, False);

    // данные второй группы ====================================================

    // не обязательно, но крайне желательно для каждой группы сделать свой FoldID
    Inc(FoldID);

    LineIndex := Add(QuarterSpace + Bulite + 'Адаптер: ',
      'VirtualBox Host-Only Ethernet Adapter', CaptionColor, ValueColor);
    // сворачиваем с этой линии
    FHighLighter.AddFolding(LineIndex, FoldID, True,
      False // группа развернута
      );

    Add(QuarterSpace + Bulite + 'Тип адаптера: ', 'MIB_IF_TYPE_ETHERNET',
      CaptionColor, ValueColor);
    Add(QuarterSpace + Bulite + 'Используемые IP адреса: ',  EmptyStr,
      CaptionColor, clNone);
    LineIndex := Add(QuarterSpace + QuarterSpace + 'IP: ',
      '192.168.1.2', ', маска подсети: ', '255.255.255.0',
      CaptionColor, ValueColor);

    // и по вот эту
    FHighLighter.AddFolding(LineIndex, FoldID, False, False);
  end;

  procedure AddTree;

    procedure FillTree(ALevel, AFoldID: Integer; const APath: string);
    var
      Mark: TGutterMarks;
      SR: TSearchRec;
      FirstLineIndex, LineIndex: Integer;
      CurrentPath: string;
    begin
      if FindFirst(APath + '*.*', faAnyFile, SR) = 0 then
      try
        repeat
          if (SR.Name = '.') or (SR.Name = '..') then
            Continue;
          CurrentPath := APath + SR.Name;

          if DirectoryExists(CurrentPath) then
          begin

            // Добавляем папку
            FirstLineIndex := SynEdit1.Lines.Add(
              QuarterSpace + StringOfChar(' ', ALevel * 4) + SR.Name);

            // Назначаем ей иконку с папкой
            Mark.InEditImageIndex := 3;
            Mark.FirstImageIndex := -1;

            // Можно и в Gutter-е назначить для избраных
            if SR.Name = 'Win32' then
              Mark.SecondImageIndex := 4
            else
              Mark.SecondImageIndex := -1;

            FHighLighter.AddGutterMark(FirstLineIndex, Mark);

            // в начале папки ставим экспандер
            FHighLighter.AddFolding(FirstLineIndex, AFoldID, True);

            // заполняем информацию по папке
            FillTree(
              ALevel + 1,           // указываем уровень для оффсетов
              SynEdit1.Lines.Count, // и "уникальный" FoldID для каждого экспандера
              IncludeTrailingPathDelimiter(CurrentPath));

            // и после заполнения папки закрываем фолдинг по последнюю линию
            LineIndex := SynEdit1.Lines.Count - 1;
            FHighLighter.AddFolding(LineIndex, AFoldID, False);

            Continue;
          end;

          // это добавление файла в папке
          LineIndex := SynEdit1.Lines.Add(
            QuarterSpace + StringOfChar(' ', ALevel * 4) + SR.Name);

          // и назначение ему иконки
          Mark.InEditImageIndex := 2;
          Mark.FirstImageIndex := -1;
          Mark.SecondImageIndex := -1;
          FHighLighter.AddGutterMark(LineIndex, Mark);

        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;

  var
    Path: string;
  begin
    Path := ExtractFilePath(ParamStr(0)) + '..\..\';
    FillTree(1, SynEdit1.Lines.Count, Path);
  end;

begin
  // чтобы правильно работал фолдинг обязательно делаем заполнение под BeginUpdate
  FHighLighter.BeginUpdate;
  try
    SynEdit1.Text := EmptyStr;
    Add('Демонстрация работы ', 'TSynEasyHighlighter', RGB(0, 114, 247));
    SynEdit1.Lines.Add(EmptyStr);
    // пробелами выделяем место под иконку
    AddHeader('     TSynEasyHighlighter поддерживает заголовки с дополнительными иконками', 0);
    SynEdit1.Lines.Add(EmptyStr);
    AddCharsWithRandomColors;
    SynEdit1.Lines.Add(EmptyStr);
    AddUrl('Поддерживаются гиперссылки: ', 'http://www.yandex.ru');
    SynEdit1.Lines.Add(EmptyStr);
    AddGutterIcon;
    SynEdit1.Lines.Add(EmptyStr);
    AddHeader(' Плагин постобработки TSynEasyPaintPlugin подсвечивает текст поиска', -1);
    SynEdit1.Lines.Add(EmptyStr);
    AddSearchedText;
    SynEdit1.Lines.Add(EmptyStr);
    AddHeader(' Экспандеры можно рисовать не на Gutter, а непосредственно в поле с текстом', -1);
    SynEdit1.Lines.Add(EmptyStr);
    AddSimpleFoldingData;
    SynEdit1.Lines.Add(EmptyStr);
    AddHeader(' А так-же можно организовать подобие дерева', -1);
    SynEdit1.Lines.Add(EmptyStr);
    AddTree;
  finally
    // на EndUpdate произойдет пересчет свернутых линий и выставление
    // актуального состояния фолдинга
    FHighLighter.EndUpdate;
  end;
end;

procedure TForm1.OnUrlClick(Sender: TObject; LineIndex: Integer;
  const URL: string; var Handled: Boolean);
begin
  Handled := MessageBox(Handle,
    PChar(Format('Произвести переход по внешней ссылке: "%s"?', [URL])),
    PChar(Application.Title), MB_YESNO) = IDNO;
end;

end.
