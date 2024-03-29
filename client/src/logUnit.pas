unit logUnit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Layouts,
  FMX.ListBox, FMX.Memo.Types, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo;

type
  TLogForm = class(TForm)
    Memo: TMemo;
    procedure ListBoxChange(Sender: TObject);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    procedure log(text : string);
  end;

var
  LogForm: TLogForm;

implementation

{$R *.fmx}

procedure TLogForm.log(text : string);
begin
  Memo.Lines.Add(text);
end;

procedure TLogForm.ListBoxChange(Sender: TObject);
begin
  Memo.ScrollBy(-MaxInt, -MaxInt, true);
end;

end.
