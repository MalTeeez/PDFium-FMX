program pdfiumfmx;

uses
  System.StartUpCopy,
  FMX.Forms,
  APIUnit in 'src\APIUnit.pas',
  FileView in 'src\FileView.pas' {FileViewForm},
  logUnit in 'src\logUnit.pas' {LogForm},
  PDFViewUnit in 'src\PDFViewUnit.pas' {PDFViewForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFileViewForm, FileViewForm);
  Application.CreateForm(TLogForm, LogForm);
  Application.CreateForm(TPDFViewForm, PDFViewForm);
  Application.Run;
end.
