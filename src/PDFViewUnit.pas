unit PDFViewUnit;

interface

uses
	{$IFDEF MSWINDOWS} Winapi.ShellAPI, Winapi.Windows, {$ENDIF MSWINDOWS}
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  Winsoft.FireMonkey.PDFium, FMX.Layouts, FMX.ListBox, FMX.Controls.Presentation, FMX.StdCtrls,
  FMX.Objects, System.ImageList, FMX.ImgList, System.IOUtils, FMX.Edit, FMX.EditBox, FMX.NumberBox,
  FMX.TreeView, System.Generics.Collections, System.Math.Vectors, FMX.Controls3D, FMX.Layers3D;

type
  TPDFViewForm = class(TForm)
    FPdf: TFPdf;
    FPdfView: TFPdfView;
    ComboBoxZoom: TComboBox;
    HeaderPanel: TPanel;
    ScrollBox: TVertScrollBox;
    SpeedButton1: TSpeedButton;
    ImageList: TImageList;
    SpeedButton2: TSpeedButton;
    PageNumLabel: TLabel;
    PageNumBox: TNumberBox;
    TreeView: TTreeView;
    BookmarkPanel: TPanel;
    eventHostItem: TTreeViewItem;
    Splitter3D1: TSplitter3D;
    BookmarkLabel: TLabel;
    BookmarkClose: TSpeedButton;
    TopPanel: TPanel;
    TreeViewPanel: TPanel;
    SpeedButton3: TSpeedButton;
    procedure FPdfViewMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,
      Y: Single);
    procedure FPdfViewMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure FPdfViewMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,
      Y: Single);
    procedure FormResize(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FPdfViewPaint(Sender: TObject; Canvas: TCanvas);
    procedure ComboBoxZoomChange(Sender: TObject);
    procedure ScrollBoxMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
      var Handled: Boolean);
    procedure FPdfViewPageChange(Sender: TObject);
    procedure ImageFirstPageClick(Sender: TObject);
    procedure ImageLastPageClick(Sender: TObject);
    procedure ImageNextPageClick(Sender: TObject);
    procedure ImagePreviousPageClick(Sender: TObject);
    procedure SpeedButtonPageNumberClick(Sender: TObject);
    procedure PageNumBoxChange(Sender: TObject);
    procedure eventHostItemClick(Sender: TObject);
  private
    { Private-Deklarationen }
    Selecting: Boolean;
    SelectionStart: Integer;
    SelectionEnd: Integer;
    PixelsPerInch: Double;
    WheelStackDelta: Integer;
    NodeItems 	: TObjectList<TTreeViewItem>;
    procedure Zoom;
    procedure log(const text: string);
    procedure addChildBookmarks(BookmarkNode: TTreeViewItem; const Bookmark: TBookmark; recursiveLayer : Integer);
  public
    { Public-Deklarationen }
    procedure loadNewPdf(const pathToPdf : string);
  end;

var
  PDFViewForm: TPDFViewForm;

implementation

{$R *.fmx}

uses logUnit, FMX.Platform, FMX.BehaviorManager, FileView;

//HELPERS
procedure TPDFViewForm.log(const text: string);
begin
  LogForm.ListBox.Items.Add(text);
end;

procedure TPDFViewForm.PageNumBoxChange(Sender: TObject);
begin
  FPdfView.PageNumber := Trunc(TNumberBox(Sender).Value);
end;

function calcHeight(width : Single; text : String): Single;
var
  x, y : Single;
  map : TBitmap;
begin
  Result := 20;
  PDFViewForm.log('got item request for width: ' + IntToStr(trunc(width)));
  map := TBitmap.Create;
  try
  	x := map.Canvas.TextWidth(text);
    PDFViewForm.log('With Text: ' + text + ' which has length: ' + IntToStr(trunc(x)));
    y := 20 * (x / width);
    if (x > width) and (y > 20) then
    begin
      Result := trunc(y * 2.0);
    end;
    PDFViewForm.log('Which was turned into: ' + IntToStr(trunc((Result))));
  finally
    map.Free;
  end;
end;

procedure TPDFViewForm.loadNewPdf(const pathToPdf : string);
var
  Bookmarks : TBookmarks;
begin
  Bookmarks := nil;
	Selecting := False;
  SelectionStart := -1;
  SelectionEnd := -1;

  FPdfView.Enabled := false;
  FPdf.Active := false;

  var PdfContent: TArray<Byte>; // PDF content
	PdfContent := TFile.ReadAllBytes(pathToPdf); // read PDF content from file to memory
	FPdf.LoadDocument(PdfContent, Length(PdfContent), true); // load PDF from memory data

  FPdf.PageNumber := 0;
  FPdfView.PageNumber := 1;

  Bookmarks := FPdf.Bookmarks;
  var
    Node : TTreeViewItem;
  var
    i    : Integer;
  TreeView.BeginUpdate;
  try
  	TreeView.Clear;
    NodeItems := TObjectList<TTreeViewItem>.Create;
    for I := 0 to Length(Bookmarks) - 1 do
    begin
    	Node := TTreeViewItem.Create(TreeView);
      Node.Text := Bookmarks[I].Title;
      Node.WordWrap := true;
      Node.Tag := Bookmarks[I].PageNumber;
      TreeView.AddObject(Node);
      Node.OnClick := PDFViewForm.eventHostItemClick;
      Node.Height := calcHeight(TreeView.Width, Node.Text);
      addChildBookmarks(Node, Bookmarks[I], 1);
      NodeItems.Add(Node);
    end;

     if TreeView.Count > 0 then
     begin
       TreeView.Visible := True;
     end;
  finally
     TreeView.EndUpdate;
  end;

  FPdfView.Active := True;
  FPdfView.Enabled := True;

  PageNumLabel.Text := 'of ' + IntToStr(FPdfView.PageCount);
  PageNumBox.Max := FPdfView.PageCount;
	Zoom;
  FPdfView.Repaint;

end;

procedure TPDFViewForm.addChildBookmarks(BookmarkNode: TTreeViewItem; const Bookmark: TBookmark; recursiveLayer : Integer);
var
  Bookmarks: TBookmarks;
  I: Integer;
  Node: TTreeViewItem;
begin
  Bookmarks := FPdf.BookmarkChildren[Bookmark];
  for I := 0 to Length(Bookmarks) - 1 do
  begin
    Node := TTreeViewItem.Create(BookmarkNode);
    Node.Text := Bookmarks[I].Title;
    Node.WordWrap := true;
    Node.Tag := Bookmarks[I].PageNumber;
    BookmarkNode.AddObject(Node);
    AddChildBookmarks(Node, Bookmarks[I], recursiveLayer + 1);
    NodeItems.Add(Node);
    Node.Height := calcHeight(TreeView.Width - (20 * recursiveLayer), Node.Text);
    Node.OnClick := PDFViewForm.eventHostItemClick;
  end;
end;

procedure TPDFViewForm.ScrollBoxMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
  var Handled: Boolean);
  var
  maxPages, currPage, tolerance:  Integer;
begin
  tolerance := trunc((Screen.Height/abs(WheelDelta)) * 37.5);
	if (WheelStackDelta + WheelDelta < WheelStackDelta) and (WheelDelta > 0)
  or (WheelStackDelta + WheelDelta > WheelStackDelta) and (WheelDelta < 0) then
  begin
    WheelStackDelta := 0;
    exit;
  end else
  begin
  	WheelStackDelta := WheelStackDelta + WheelDelta;
  end;
  maxPages := FPdfView.PageCount;
  currPage := FPdfView.PageNumber;
  if (WheelStackDelta < -tolerance) and (currPage < maxPages) then
  begin
    FPdfView.PageNumber := FPdfView.PageNumber + 1;
    WheelStackDelta := 0;
    ScrollBox.ScrollBy(MaxInt, MaxInt);
  end else if (WheelStackDelta > tolerance) and (currPage > 1) then
  begin
    FPdfView.PageNumber := currPage - 1;
    WheelStackDelta := 0;
    //ScrollBox.ScrollBy(0,-100);
  end;
  WheelDelta := 0;
end;

procedure TPDFViewForm.SpeedButtonPageNumberClick(Sender: TObject);
var
  PageNumber: string;
  NewPageNumber: Integer;
begin
  PageNumber := IntToStr(FPdfView.PageNumber);
  if InputQuery('Select page', 'Page number: ', PageNumber) then
  begin
    NewPageNumber := StrToIntDef(PageNumber, FPdfView.PageNumber);
    if (NewPageNumber >= 1) and (NewPageNumber <= FPdfView.PageCount) then
      FPdfView.PageNumber := NewPageNumber;
  end;
end;

procedure TPDFViewForm.Zoom;
var
  PdfPageWidth, PdfPageHeight: Double;
  Zoom: Double;
begin
  if FPdfView.Active then
  begin
    if FPdfView.Rotation in [ro0, ro180] then
    begin
      PdfPageWidth := FPdfView.PageWidth;
      PdfPageHeight := FPdfView.PageHeight;
    end
    else
    begin
      PdfPageWidth := FPdfView.PageHeight;
      PdfPageHeight := FPdfView.PageWidth;
    end;

    case ComboBoxZoom.ItemIndex of
      0: Zoom := 0.1;
      1: Zoom := 0.25;
      2: Zoom := 0.5;
      3: Zoom := 0.75;
      5: Zoom := 1.25;
      6: Zoom := 1.5;
      7: Zoom := 2.0;
      8: Zoom := 4.0;
      10: // Zoom to page
          if ScrollBox.Width / PdfPageWidth > ScrollBox.Height / PdfPageHeight then
            Zoom := ScrollBox.Height / PointsToPixels(PdfPageHeight, PixelsPerInch) // zoom to height
          else
            Zoom := ScrollBox.Width / PointsToPixels(PdfPageWidth, PixelsPerInch); // zoom to width

      11: Zoom := (ScrollBox.Width - 24) / PointsToPixels(PdfPageWidth, PixelsPerInch); // page width
      else Zoom := 1.0;
    end;

    // set size
    FPdfView.Size.Size := TSizeF.Create(
      PointsToPixels(Zoom * PdfPageWidth, PixelsPerInch),
      PointsToPixels(Zoom * PdfPageHeight, PixelsPerInch));
  end;
end;

procedure OSExecute(const ACommand: string);
begin
{$IFDEF MSWINDOWS}
  ShellExecute(0, 'OPEN', PChar(ACommand), '', '', SW_SHOWNORMAL);
{$ENDIF MSWINDOWS}
end;

function IsAlphaNumeric(C: Char): Boolean;
begin
  Result := CharInSet(C, ['a'..'z', 'A'..'Z', '0'..'9']);
end;

procedure TPDFViewForm.ComboBoxZoomChange(Sender: TObject);
begin
  Zoom;
end;

procedure TPDFViewForm.eventHostItemClick(Sender: TObject);
begin
	log(IntToStr(trunc((TTreeViewItem(Sender).Width))));
  //TTreeViewItem(Sender).Height := calcHeight(TTreeViewItem(Sender));
end;

procedure TPDFViewForm.FormCreate(Sender: TObject);
var DeviceBehavior: IDeviceBehavior;
begin
  PixelsPerInch := 96;
  WheelStackDelta := 0;
  if TBehaviorServices.Current.SupportsBehaviorService(IDeviceBehavior, DeviceBehavior, Self) then
    PixelsPerInch := DeviceBehavior.GetDisplayMetrics(Self).PixelsPerInch;
  ScrollBox.AniCalculations.Animation := true;
end;

procedure TPDFViewForm.FormResize(Sender: TObject);
begin
  Zoom;
end;

procedure TPDFViewForm.FPdfViewMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Single);
const
  Tolerance = 2.0;
var
  LinkIndex: Integer;
begin
  LinkIndex := FPdfView.WebLinkAtPos(Round(X), Round(Y));
  if LinkIndex <> -1 then
  begin
    OSExecute(FPdfView.WebLink[LinkIndex].Url);
    Exit;
  end;

  LinkIndex := FPdfView.LinkAnnotationAtPos(Round(X), Round(Y));
  if LinkIndex <> -1 then
  begin
    with FPdfView.LinkAnnotation[LinkIndex] do
      case Action of
        acGotoRemote, acLaunch, acUri:
          OSExecute(ActionPath);
        else
          if (PageNumber >= 1) and (PageNumber <= FPdfView.PageCount) then
            FPdfView.PageNumber := PageNumber;
      end;
    Exit;
  end;

  if ssDouble in Shift then
  begin
    // select current word
    SelectionStart := FPdfView.CharacterIndexAtPos(Round(X), Round(Y), Tolerance, Tolerance);
    SelectionEnd := SelectionStart;
    if SelectionStart >= 0 then
    begin
      while (SelectionStart > 0) and IsAlphaNumeric(FPdfView.Character[SelectionStart - 1]) do
        Dec(SelectionStart);

      while (SelectionEnd < FPdfView.CharacterCount - 1) and IsAlphaNumeric(FPdfView.Character[SelectionEnd + 1]) do
        Inc(SelectionEnd);

      FPdfView.Repaint;
    end;
  end
  else
  begin
    Selecting := True;
    SelectionStart := -1;
    SelectionEnd := -1;
  end;
end;

procedure TPDFViewForm.FPdfViewMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
const
  Tolerance = 2.0;
var
  SelectedIndex: Integer;
  NeedRepaint: Boolean;
begin
  SelectedIndex := FPdfView.CharacterIndexAtPos(Round(X), Round(Y), Tolerance, Tolerance);
  if (not Selecting) and (FPdfView.WebLinkAtPos(Round(X), Round(Y)) <> -1) then
    FPdfView.Cursor := crHandPoint
  else if (not Selecting) and (FPdfView.LinkAnnotationAtPos(Round(X), Round(Y)) <> -1) then
    FPdfView.Cursor := crHandPoint
  else if SelectedIndex >= 0 then
    FPdfView.Cursor := crIBeam
  else
    FPdfView.Cursor := crDefault;

  if Selecting then
    if SelectedIndex >= 0 then
    begin
      NeedRepaint := False;

      if SelectionStart = -1 then
      begin
        SelectionStart := SelectedIndex;
        NeedRepaint := True;
      end;

      if SelectionEnd <> SelectedIndex then
      begin
        SelectionEnd := SelectedIndex;
        NeedRepaint := True;
      end;

      if NeedRepaint then
        FPdfView.Repaint;
    end;
end;

procedure TPDFViewForm.FPdfViewMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,
  Y: Single);
var
  Text: string;
  Clipboard: IFMXClipboardService;
begin
  if Selecting then
  begin
    Selecting := False;
    if (SelectionStart >= 0) and (SelectionEnd >= 0) then
    begin
      if SelectionEnd < SelectionStart then
        Text := FPdfView.Text(SelectionEnd, SelectionStart - SelectionEnd + 1)
      else
        Text := FPdfView.Text(SelectionStart, SelectionEnd - SelectionStart + 1);

      if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, IInterface(Clipboard)) then
        Clipboard.SetClipboard(Text);
    end;
  end;

end;

procedure TPDFViewForm.FPdfViewPageChange(Sender: TObject);
begin
  Selecting := False;
  SelectionStart := -1;
  SelectionEnd := -1;

  PageNumBox.Value := FPdfView.PageNumber;
  Zoom;
  FPdfView.Repaint;
end;

procedure TPDFViewForm.FPdfViewPaint(Sender: TObject; Canvas: TCanvas);
begin
if FPdfView.Enabled then
  begin
    FPdfView.PaintSelection(SelectionStart, SelectionEnd, TAlphaColor($8080C0F0));
  end;
end;

procedure TPDFViewForm.ImageFirstPageClick(Sender: TObject);
begin
	FPdfView.PageNumber := 1;
end;

procedure TPDFViewForm.ImageLastPageClick(Sender: TObject);
begin
	FPdfView.PageNumber := FPdfView.PageCount;
end;

procedure TPDFViewForm.ImageNextPageClick(Sender: TObject);
begin
  if FPdfView.PageNumber < FPdfView.PageCount then
  begin
    FPdfView.PageNumber := FPdfView.PageNumber + 1;
      PageNumLabel.Text := 'of ' + IntToStr(FPdfView.PageCount);
  end;

end;

procedure TPDFViewForm.ImagePreviousPageClick(Sender: TObject);
begin
	if FPdfView.PageNumber > 1 then
  begin
    FPdfView.PageNumber := FPdfView.PageNumber - 1;
  end;
end;

end.
