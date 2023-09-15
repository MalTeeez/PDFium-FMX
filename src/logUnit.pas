unit logUnit;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Layouts,
  FMX.ListBox;

type
  TLogForm = class(TForm)
    ListBox: TListBox;
    procedure FormCreate(Sender: TObject);
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
  ListBox.Items.Add(text);
end;

procedure TLogForm.FormCreate(Sender: TObject);
begin
  ListBox.AniCalculations.Animation := true;
end;

procedure TLogForm.ListBoxChange(Sender: TObject);
begin
  ListBox.ScrollToItem(ListBox.ListItems[ListBox.Count]);
end;

end.
