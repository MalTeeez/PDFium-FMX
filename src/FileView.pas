unit FileView;

interface

uses
	{$IFDEF MSWINDOWS} Winapi.ShellAPI, Winapi.Windows, {$ENDIF MSWINDOWS}
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.ListView.Types, FMX.ListView.Appearances, FMX.ListView.Adapters.Base,
  FMX.ListView, IOUtils, FMX.Layouts, FMX.TreeView, FMX.ListBox,
  System.ImageList, FMX.ImgList, Generics.Collections,
  FMX.Controls.Presentation, FMX.Edit, FMX.StdCtrls, FMX.EditBox, FMX.NumberBox, FMX.Objects,
  System.Rtti, FMX.Grid.Style, FMX.Grid, FMX.ScrollBox, REST.Types, REST.Client,
  Data.Bind.Components, Data.Bind.ObjectScope, FMX.Colors, Winsoft.FireMonkey.PDFium, FMX.Ani;

type
  TFileViewForm = class(TForm)
    TreeView: TTreeView;
    eventhostItem: TTreeViewItem;
    ImageList: TImageList;
    NumberBox1: TNumberBox;
    NumberBox2: TNumberBox;
    NumberBox3: TNumberBox;
    NumberBox4: TNumberBox;
    NumberBox5: TNumberBox;
    NumberBox6: TNumberBox;
    HeaderPanel: TPanel;
    SearchImage: TImage;
    SearchEdit: TEdit;
    SearchLabel: TLabel;
    StringGrid: TStringGrid;
    TitleColumn: TStringColumn;
    VersionColumn: TStringColumn;
    ValidToColumn: TStringColumn;
    CreatedOnColumn: TStringColumn;
    MatchesColumn: TStringColumn;
    GlyphColumn: TGlyphColumn;
    BackImage: TImage;
    SearchHeaderLabel: TLabel;
    RESTRequest1: TRESTRequest;
    RESTClient1: TRESTClient;
    RESTResponse1: TRESTResponse;
    APITest: TButton;
    Label1: TLabel;
    StyleBook: TStyleBook;
    SearchFPDF: TFPdf;
    SearchBar: TProgressBar;
    LoadingPanel: TPanel;
    SearchingAni: TAniIndicator;
    SearchingLabel: TLabel;
    FloatAnimation1: TFloatAnimation;
    SearchingCurrentLabel: TLabel;
    procedure FormShow(Sender: TObject);
    procedure eventhostItemDblClick(Sender: TObject);
    procedure eventhostItemPaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
    procedure eventhostItemClick(Sender: TObject);
    procedure NumberBox1Change(Sender: TObject);
    procedure eventhostItemMouseEnter(Sender: TObject);
    procedure eventhostItemMouseLeave(Sender: TObject);
    procedure SearchImageClick(Sender: TObject);
    procedure SearchEditKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure StringGridHeaderClick(Column: TColumn);
    procedure BackImageClick(Sender: TObject);
    procedure BackImageMouseEnter(Sender: TObject);
    procedure BackImageMouseLeave(Sender: TObject);
    procedure SearchImageMouseEnter(Sender: TObject);
    procedure SearchImageMouseLeave(Sender: TObject);
    procedure StringGridCellClick(const Column: TColumn; const Row: Integer);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure APITestClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private-Deklarationen }
  	hover 					: Boolean;
  	searchItemData 	: TStringList;
    searchMatches   : Integer;
    searching				: Boolean;
    function searchPDFContents(fpath, searchString : String): Integer;
    function itemsThatContainText(searchString, parentDir: string; searchContents : boolean): TDictionary<TTreeViewItem, Integer>;
    procedure log(text: string);
  public
    { Public-Deklarationen }
  end;

var
  FileViewForm		: TFileViewForm;
  Items						: TDictionary<TTreeViewItem, String>;
  SearchItems 		: TDictionary<Integer, String>;

implementation

{$R *.fmx}

uses logUnit, PDFViewUnit, APIUnit;

//HELPERS
procedure TFileViewForm.log(text: string);
begin
  LogForm.log(text);
end;

function getKeyWithValue(Value: String): TTreeViewItem;
var
  Pair	: TPair<TTreeViewItem, String>;
begin
	Result := nil;
	for Pair in Items do
  begin
    if Pair.Value = Value then
    begin
      Result := Pair.Key;
      break;
    end;
  end;
end;

function getItemType(path: string): Integer; overload;
begin
	if TFileAttribute.faDirectory in IOUtils.TPath{|TFile|TDirectory}.GetAttributes(path) then
  begin  // Item is Folder
    Result := 0;
  end else
  begin
  	if IOUtils.TPath.GetExtension(IOUtils.TPath.GetFileName(path)) = '.pdf' then
  	begin  // Item is Pdf
    	Result := 1;
  	end else  // Item is not Pdf
    	Result := 2;
  end;
end;

function getItemType(item: TTreeViewItem): Integer; overload;
var
  path : string;
begin
  path := Items[item];
	if TFileAttribute.faDirectory in IOUtils.TPath{|TFile|TDirectory}.GetAttributes(path) then
  begin  // Item is Folder
    Result := 0;
  end else
  begin
  	if IOUtils.TPath.GetExtension(IOUtils.TPath.GetFileName(path)) = '.pdf' then
  	begin  // Item is Pdf
    	Result := 1;
  	end else  // Item is not Pdf
    	Result := 2;
  end;
end;

function itemByPath(path: string): TTreeViewItem;
var
  item	: TTreeViewItem;
begin
	Result := nil;
  item := getKeyWithValue(path);
  if (item <> nil) then
  begin
  	Result := item;
  end;
end;

function TFileViewForm.searchPDFContents(fpath, searchString : String): Integer;
const
  NewLine = #13#10;
var
  i							 : Integer;
  FileName, line : string;
begin
	Result := 0;
  try
    SearchFPDF.FileName := fpath;
    SearchFPDF.PageNumber := 0;
    SearchFPDF.Active := True;
    for i := 1 to SearchFPDF.PageCount do
    begin
    	SearchFPDF.PageNumber := i;
      for line in SearchFPDF.Text.Split([NewLine]) do
      begin
      	if (line <> '') and (line.Contains(searchString)) then
        begin
        	Result := Result + 1;
        end;
      end;
      Application.ProcessMessages;
    end;
	finally
    SearchFPDF.Active := False;
  end;
end;

function TFileViewForm.itemsThatContainText(searchString, parentDir: string; searchContents : boolean): TDictionary<TTreeViewItem, Integer>;
var
  Value   			: String;
  matches     	: Integer;
  item          : TTreeViewItem;
begin
	Result := System.Generics.Collections.TDictionary<TTreeViewItem, Integer>.Create;
  SearchBar.Max := Items.Count;
  for Value in Items.Values do
  begin
    //Animate & Update LoadingPanel's Components
    FloatAnimation1.StopValue := SearchBar.Value + 1;
    FloatAnimation1.Start;
    SearchingCurrentLabel.Text := 'Document: ' + IOUtils.TPath.GetFileName(Value);
    Application.ProcessMessages;

  	if IOUtils.TPath.GetFileName(Value).Contains(searchString) and IOUtils.TPath.GetFullPath(IOUtils.TDirectory.GetParent(Value)).Contains(parentDir) then
    begin
    	Result.Add(getKeyWithValue(Value), 0);
    end;
    if (searchContents) and (getItemType(Value) = 1) then
    begin
      matches := FileViewForm.searchPDFContents(Value, searchString);
      if (matches > 0) then
      begin
      	item := getKeyWithValue(Value);
        searchMatches := searchMatches + matches;
      	if (Result.ContainsKey(item)) then
      	begin
        	Result[item] := matches;
      	end else
      	begin
        	Result.Add(item, matches);
      	end;
      end;
    end;
    FloatAnimation1.Stop;
  end;
end;


procedure viewPDF(fpath: string);
begin
	with PDFViewForm do
  begin
  	Visible := true;
    loadNewPdf(fpath);
  end;
end;


procedure TFileViewForm.eventhostItemDblClick(Sender: TObject);
var
item	: TTreeViewItem;
begin
  item := TTreeViewItem(Sender);
	if (getItemType(Items[item]) = 1 ) then
  begin
  	log('File Open Handle Event for ' + Items[item].Replace('\','/'));
    viewPDF(Items[item].Replace('\','/'));
  	//ShellExecute(0, 'OPEN', PChar('Firefox.lnk'), Pchar('file:///' + Items[item].Replace('\','/')), '', SW_SHOW);
  end;
end;


procedure TFileViewForm.eventhostItemMouseEnter(Sender: TObject);
begin
  hover := true;
end;

procedure TFileViewForm.eventhostItemMouseLeave(Sender: TObject);
begin
  hover := false;
end;

procedure TFileViewForm.eventhostItemPaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
var
  rect1	: TRectF;
  item  : TTreeViewItem;
  name  : String;
begin
	//log('painting for item');
  item := TTreeViewItem(Sender);
  name := IOUtils.TPath.GetFileName(Items[item]);
  rect1 := TRectF.Create(TPoint.Create(0,0),10,10);
  with Canvas do
  begin
    BeginScene;
  	// Test Red Dot
    Canvas.Fill := TBrush.Create(TBrushKind.Solid, TAlphaColors.Red);
    DrawRect(rect1, 0, 0, AllCorners, 100, TCornerType.InnerLine);
    FillRect(rect1, 10, 10, AllCorners, 100, TCornerType.InnerLine);

    EndScene;


    BeginScene;
    //Date Text (comes first cuz overlay)
    Canvas.Fill := TBrush.Create(TBrushKind.Solid, TAlphaColor($FF777777));
    Canvas.Font.Family := 'Inter';
    Canvas.Font.Size   :=  11;
    Canvas.Font.Style  := [];
    Canvas.FillText(TRectF.Create(TPointF.Create(52, 13), Screen.Size.Width - 25, 25), 'Created: 01/12/2020  Valid to: 03/25/2025', false, 100,
    [TFillTextFlag.RightToLeft],
    TTextAlign.Trailing,
    TTextAlign.Center);



    //Main Text
    Canvas.Fill := TBrush.Create(TBrushKind.Solid, TAlphaColor($FF484848));
    //Canvas.Font.Family := 'Segoe UI';
    Canvas.Font.Size   :=  16;
    Canvas.Font.Style  := [];
    Canvas.FillText(TRectF.Create(TPointF.Create(45, -4), Screen.Size.Width - 25, 30), name, false, 95,
    [TFillTextFlag.RightToLeft],
    TTextAlign.Trailing,
    TTextAlign.Center);

    EndScene;
    { For Debug Drawing Positions
    Canvas.Font.Size   :=  16;
    Canvas.Fill := TBrush.Create(TBrushKind.Solid, TAlphaColors.Black);

    Canvas.FillText(TRectF.Create(TPointF.Create(Single(NumberBox1.Value), Single(NumberBox2.Value)), Screen.Size.Width - 25, Single(NumberBox3.Value)), name, false, 100,
    [TFillTextFlag.RightToLeft],
    TTextAlign.Trailing,
    TTextAlign.Center);

    Canvas.Font.Size   :=  11;
    Canvas.Fill := TBrush.Create(TBrushKind.Solid, TAlphaColor($FF777777));
    Canvas.FillText(TRectF.Create(TPointF.Create(Single(NumberBox4.Value), Single(NumberBox5.Value)), Screen.Size.Width - 25, Single(NumberBox6.Value)), name, false, 100,
    [TFillTextFlag.RightToLeft],
    TTextAlign.Trailing,
    TTextAlign.Center); //}

  end;
end;

procedure addNode(text, path: string; itype: integer); stdcall deprecated;
var
  Node :  TTreeViewItem;
begin
  Node := TTreeViewItem.Create(FileViewForm);
  Node.Text := ' ' + text;
  Node.StyledSettings := Node.StyledSettings - [TStyledSetting.Size, TStyledSetting.Family];
  Node.TextSettings.Font.SetSettings('Poppins', 16, TFontStyleExt.Default);
  Node.OnDblClick := FileViewForm.eventhostItemDblClick;
  Node.OnPaint := FileViewForm.eventhostItemPaint;
  Node.ImageIndex := itype;
  Node.Parent := FileViewForm.TreeView;
  Items.Add(Node, path);
end;

procedure TFileViewForm.BackImageMouseEnter(Sender: TObject);
begin
  BackImage.Opacity := 1.0;
end;

procedure TFileViewForm.BackImageMouseLeave(Sender: TObject);
begin
  BackImage.Opacity := 0.8;
end;

procedure TFileViewForm.Button1Click(Sender: TObject);
begin
  searchPDFContents('C:\Users\Mika\Documents\Delphi_Projects\PDFIUM-FMX\examplefolder\doc\wien_amd02_20230518.pdf'
  , 'Wien');
end;

procedure TFileViewForm.SearchEditKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
	if Key = 13 then
  begin
    SearchImage.OnClick(FileViewForm);
  end;
end;

procedure TFileViewForm.eventhostItemClick(Sender: TObject);
begin
  //log('before tag: ' + IntToStr(TTreeViewItem(Sender).Tag) + ' | after tag: ' +
  //IntToStr(itemByPath(Files[TTreeViewItem(Sender).Tag]).Tag));
  if getItemType(TTreeViewItem(Sender)) = 0 then
  begin
    if TTreeViewItem(Sender).IsExpanded = true then
    begin
       TTreeViewItem(Sender).Collapse;
       TTreeViewItem(Sender).IsExpanded := false;
  	end else
  	begin
  		TTreeViewItem(Sender).Expand;
      TTreeViewItem(Sender).IsExpanded := true;
  	end;
  end;
end;

procedure addToNode(parentPath, path: string; itype: integer);
var
  Node :  TTreeViewItem;
begin
  Node := TTreeViewItem.Create(nil);
  //Parent
  if IOUtils.TPath.GetFileName(parentPath) = '..' then
  begin  // Parent Node is Root
    Node.Parent := FileViewForm.TreeView;
  end else
  begin // Parent Node is Folder
    Node.Parent := itemByPath(IOUtils.TPath.GetFullPath(parentPath));
    //log('Found parent: ' + itemByPath(IOUtils.TPath.GetFullPath(parentPath)).Text + ' for item: ' + text);
  end;
  { Text & Font }
  //Node.Text := IOUtils.TPath.GetFileName(path); //Drawing done at painttime now
  Node.StyledSettings := Node.StyledSettings - [TStyledSetting.Size, TStyledSetting.Family];
  Node.TextSettings.Font.SetSettings('Segoe UI', 16, TFontStyleExt.Default);
  //Events
  Node.OnDblClick := FileViewForm.eventhostItemDblClick;
  Node.OnPaint := FileViewForm.eventhostItemPaint;
  Node.OnClick := FileViewForm.eventhostItemClick;
  //Icon
  Node.ImageIndex := itype;

  Items.Add(Node, path);
end;


procedure initSmoothScrolling();
begin
	with FileViewForm do
  begin
    TreeView.AniCalculations.Animation := true;
    StringGrid.AniCalculations.Animation := true;
  end;
end;

procedure TFileViewForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
	Application.ProcessMessages;
  LogForm.Close;
  PDFViewForm.Close;
  Application.Terminate;
end;

procedure TFileViewForm.FormShow(Sender: TObject);
var
  path	: string;
begin   //TODO: Maybe sort by files / folders first, then alphabetically, TreeView Sort: https://pastebin.com/nUZJ7gyD
  Items 			:= System.Generics.Collections.TDictionary<TTreeViewItem, String>.Create;
  SearchItems := System.Generics.Collections.TDictionary<Integer, String>.Create;
  searchItemData := TStringList.Create;
  hover 			:= false;
  searching   := false;
  initSmoothScrolling;
  for path in IOUtils.TDirectory.GetFileSystemEntries('../../',IOUtils.TSearchOption.soAllDirectories, nil) do begin
    try
        addToNode(
        	IOUtils.TPath.GetDirectoryName(path), {Name of parent folder / root}
        	IOUtils.TPath.GetFullPath(path),      {Full Path (not relative)}
        	getItemType(path));           				{Type of item, 0 = folder, 1 = pdf, 2 = other file}
    except
      // Chuck Norris doesn't get Errors, Errors get Chuck Norris
    end;
  end;
end;


procedure resetSearchGrid();
begin
  SearchItems.Clear;
  with FileViewForm do
  begin
    StringGrid.RowCount := 0;
  end;
end;

{1,     2,       3,       4,         5      }
{Title, Version, ValidTo, CreatedOn, Matches}
procedure addSearchResultRow(path: string);
var
i, row	: integer;
begin
  with FileViewForm do
  begin
    StringGrid.RowCount := StringGrid.RowCount + 1;
    StringGrid.Cells[0,StringGrid.RowCount-1] := '1';
    SearchItems.Add(StringGrid.RowCount-1, path);
  	for i := 0 to 4 do
  	begin
       StringGrid.Cells[i+1,StringGrid.RowCount-1] := SearchItemData[i];
  	end;
  end;
end;

procedure TFileViewForm.APITestClick(Sender: TObject);
begin
   log(stringFromAPI('value'));
end;

procedure TFileViewForm.BackImageClick(Sender: TObject);
begin
	StringGrid.Enabled := false;
  StringGrid.Opacity := 0.75;
  StringGrid.Visible := false;
	resetSearchGrid;
  //Switch to File View
  SearchImage.Visible := true;
  SearchLabel.Visible := true;
  BackImage.Visible := false;
  SearchHeaderLabel.Text := '';
  SearchHeaderLabel.Visible := false;
	SearchEdit.Visible := true;
  TreeView.Visible := true;
end;

procedure TFileViewForm.SearchImageClick(Sender: TObject);
var
	item	 			 : TPair<TTreeViewItem, Integer>;
	searchresult : TDictionary<TTreeViewItem, Integer>;
	itemType     : Integer;
  searchContext: String;
begin
	if (not searching) then
  begin
		//Switch to Search View
  	StringGrid.Visible := true;
		resetSearchGrid;
  	TreeView.Visible := false;
  	SearchImage.Visible := false;
  	SearchLabel.Visible := false;
  	BackImage.Visible := true;
  	SearchHeaderLabel.Visible := true;
    //Show Loading Screen
    LoadingPanel.Visible := true;
    Application.ProcessMessages;

    case getItemType(TreeView.Selected) of
    	//If Folder, get Folder name
      0: 		searchContext := IOUtils.TPath.GetFileName(Items[TreeView.Selected]);
      //File Name of Parent Folder of Path of currently selected TreeView Item
      else 	searchContext := IOUtils.TPath.GetFileName(IOUtils.TDirectory.GetParent(Items[TreeView.Selected]));
    end;

    log('Search Context is: ' + searchContext);
    //Search with Edit.Text and in currently selected Item Context
    searchMatches := 0;
		searchresult := itemsThatContainText(SearchEdit.Text, searchContext, true);
  	SearchHeaderLabel.Text := 'Found ' + IntToStr(searchMatches) + ' matches of "'
  		+ SearchEdit.Text + '" in ' + IntToStr(searchresult.Count) + ' files.';
		SearchEdit.Visible := false;
    //Load Search Results into StringGrid
  	for item in searchresult do
  	begin
    	itemType := getItemType(Items[item.Key]);
    	if itemType = 1 then
    	begin
      	SearchItemData.Clear;
      	SearchItemData.AddStrings([IOUtils.TPath.GetFileName(Items[item.Key]),
      		'1.0', '18/03/2024', '01/08/2020', IntToStr(item.Value)]);
      	addSearchResultRow(Items[item.Key]);
    	end;
  	end;
    LoadingPanel.Visible := false;
    StringGrid.Enabled := true;
    StringGrid.Opacity := 1.0;
  end;
end;

procedure TFileViewForm.SearchImageMouseEnter(Sender: TObject);
begin
  SearchImage.Opacity := 1.0;
end;

procedure TFileViewForm.SearchImageMouseLeave(Sender: TObject);
begin
  SearchImage.Opacity := 0.8;
end;


procedure TFileViewForm.StringGridCellClick(const Column: TColumn; const Row: Integer);
begin
  viewPDF(SearchItems[Row].Replace('\','/'));
end;

//HOW THE HECK DOES THIS WORK
procedure TFileViewForm.StringGridHeaderClick(Column: TColumn);
var
i, tag 	: integer;
col 		: TStringList;
begin
	tag := Column.Tag;
  //log('Col click for col: ' + IntToStr(tag));
  if (tag = 0) then
    exit;

  col := TStringList.Create;
  for i := 0 to StringGrid.RowCount - 1 do
  begin
    col.Add(StringGrid.Cells[tag, i]);
  end;
  col.Sort;
  for i := 0 to StringGrid.RowCount - 1 do
  begin
    StringGrid.Cells[tag, i] := col[i];
  end;
end;

procedure TFileViewForm.NumberBox1Change(Sender: TObject);
begin
  TreeView.Repaint;
end;


end.
