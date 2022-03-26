program SynEasyHighlighterDemo;

uses
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  SynEasyHighlighter in '..\..\Source\SynEasyHighlighter.pas',
  SynEdit in '..\..\Source\SynEdit.pas',
  SynEditCodeFolding in '..\..\Source\SynEditCodeFolding.pas',
  SynEditHighlighter in '..\..\Source\SynEditHighlighter.pas',
  SynEditTypes in '..\..\Source\SynEditTypes.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
