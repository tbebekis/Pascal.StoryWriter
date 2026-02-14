unit o_app;

{$MODE DELPHI}{$H+}

interface

uses
  Classes
  ,SysUtils
  , Forms
  , Controls
  ,ComCtrls
  ,Dialogs
  , DB
  , DBCtrls
  , DBGrids
  //,Regex
  ,RegExpr

  ,Tripous
  ,Tripous.Forms.PagerHandler

  ,o_Entities
  ,o_AppSettings


  ;

type

  TItemListChangedEvent = procedure(Sender: TObject; ItemType: TItemType) of object;
  TItemChangedEvent = procedure(Sender: TObject; Item: TBaseItem) of object;
  TSearchTermIsSetEvent = procedure(Sender: TObject; const Term: string) of object;

  { App }

  App = class
  private
    class var fOnCategoryListChanged: TNotifyEvent;
    class var fOnComponentListChanged: TNotifyEvent;
    class var fOnProjectMetricsChanged: TNotifyEvent;
    class var fOnTagListChanged: TNotifyEvent;
    class var fOnProjectOpened: TNotifyEvent;
    class var fOnProjectClosed: TNotifyEvent;
    class var FOnItemListChanged: TItemListChangedEvent;
    class var FOnItemChanged: TItemChangedEvent;
    class var FOnSearchTermIsSet: TSearchTermIsSetEvent;

    class var fContentPagerHandler: TPagerHandler;
    class var fSideBarPagerHandler: TPagerHandler;
    class var fMainForm: TForm;
    class var FSyncLock: TSyncObject;
    class var FEnglishLettersRegex: TRegExpr;
    class var FZoomFactor: Double;
    class var fProject: TProject;
    class var fSettings: TAppSettings;

    public const
      SInvalidTitle = 'Invalid title %s.';
      SValidTitle =
        LineEnding +
        'A valid title' + LineEnding +
        '  • can contain only letters, numbers and spaces' + LineEnding +
        '  • cannot contain special characters' + LineEnding +
        '  • cannot start with a number' + LineEnding +
        '  • must be in English' + LineEnding;

      SInvalidTitleErrorMessage = SInvalidTitle + SValidTitle;

      class procedure DoProjectOpened();
      class procedure DoProjectClosed();
      class procedure DoItemListChanged(ItemType: TItemType);
      class procedure DoItemChanged(Item: TBaseItem);
      class procedure DoSearchTermIsSet(const Term: string);

      class procedure DoCategoryListChanged();
      class procedure DoTagListChanged();
      class procedure DoComponentListChanged();
      class procedure DoProjectMetricsChanged();

      class function GetIsInitialized: Boolean; static;
  public
    { construction }
    class constructor Create();
    class destructor Destroy();

    class procedure Initialize(AMainForm: TForm);

    // ● message boxes
    class procedure ErrorBox(const Message: string);
    class procedure WarningBox(const Message: string);
    class procedure InfoBox(const Message: string);
    class function QuestionBox(const Message: string): Boolean;

    { Returns true if the text contains the specified whole word }
    class function ContainsWord(const Text: string; const WordToFind: string): Boolean;
    class function ContainsText(const Instance: string; const Value: string): Boolean;

    // ● filenames and paths
    class function IsValidFileName(const Title: string; ShowMessage: Boolean): Boolean;
    class procedure CheckValidFileName(const Title: string);

    // ● UI
    class procedure ClearPageControl(APageControl: TPageControl);

    // ● Grid
    class procedure InitializeReadOnly(Grid: TDbGrid);
    class procedure AddColumn(Grid: TDbGrid; const FieldName: string; const Title: string = '');

    // ● project
    class procedure CreateNewProject();
    class procedure CloseProject();
    class procedure OpenProject();
    class procedure LoadProject(const FolderPath: string);
    class procedure LoadLastProject();

    // ● project statistics
    class procedure StartProjectStatsTimer();
    class procedure StopProjectStatsTimer();

    // ● miscs
    class procedure DisplayFileExplorer(const FileOrFolderPath: string);
    class function ShowFolderDialog(var FolderPath: string): Boolean;
    class procedure ShowTranslator();

    class procedure CloseAllUi();
    class procedure ShowSideBarPages();
    class procedure ShowSettingsDialog();

    // ● properties
    class property IsInitialized: Boolean read GetIsInitialized;
    class property Settings: TAppSettings read fSettings;

    class property MainForm: TForm read fMainForm;
    class property SideBarPagerHandler : TPagerHandler read fSideBarPagerHandler write fSideBarPagerHandler;
    class property ContentPagerHandler : TPagerHandler read fContentPagerHandler write fContentPagerHandler;

    class property CurrentProject: TProject read fProject write fProject;
    class property ZoomFactor: Double read FZoomFactor write FZoomFactor;

    // ● events
    class property OnProjectOpened: TNotifyEvent read fOnProjectOpened write fOnProjectOpened;
    class property OnProjectClosed: TNotifyEvent read fOnProjectClosed write fOnProjectClosed;
    class property OnItemListChanged: TItemListChangedEvent read FOnItemListChanged write FOnItemListChanged;
    class property OnItemChanged: TItemChangedEvent read FOnItemChanged write FOnItemChanged;
    class property OnSearchTermIsSet: TSearchTermIsSetEvent read FOnSearchTermIsSet write FOnSearchTermIsSet;

    class property OnCategoryListChanged: TNotifyEvent read fOnCategoryListChanged write fOnCategoryListChanged;
    class property OnTagListChanged: TNotifyEvent read fOnTagListChanged write fOnTagListChanged;
    class property OnComponentListChanged: TNotifyEvent read fOnComponentListChanged write fOnComponentListChanged;
    class property OnProjectMetricsChanged: TNotifyEvent read fOnProjectMetricsChanged write fOnProjectMetricsChanged;
  end;

implementation

uses
   LazUTF8
  ,Process
  ,System.UITypes
  ,jsonparser
  ,fpjson

  ,Tripous.Logs

  //,f_MainForm
  ,fr_CategoryList
  ,fr_StoryList
  ;



{ App }

class procedure App.DoProjectOpened();
begin
  if Assigned(fOnProjectOpened) then
      fOnProjectOpened(nil);
end;

class procedure App.DoProjectClosed();
begin
  if Assigned(FOnProjectClosed) then
      FOnProjectClosed(nil);
end;

class procedure App.DoItemListChanged(ItemType: TItemType);
begin
  if Assigned(FOnItemListChanged) then
    FOnItemListChanged(nil, ItemType);
end;

class procedure App.DoItemChanged(Item: TBaseItem);
begin
  if Assigned(FOnItemChanged) then
    FOnItemChanged(nil, Item);
end;

class procedure App.DoSearchTermIsSet(const Term: string);
begin
  if Assigned(FOnSearchTermIsSet) then
    FOnSearchTermIsSet(nil, Term);
end;

class procedure App.DoCategoryListChanged();
begin
  if Assigned(fOnCategoryListChanged) then
      fOnCategoryListChanged(nil);
end;

class procedure App.DoTagListChanged();
begin
  if Assigned(fOnTagListChanged) then
      fOnTagListChanged(nil);
end;

class procedure App.DoComponentListChanged();
begin
  if Assigned(fOnComponentListChanged) then
      fOnComponentListChanged(nil);
end;

class procedure App.DoProjectMetricsChanged();
begin
  if Assigned(fOnProjectMetricsChanged) then
      fOnProjectMetricsChanged(nil);
end;

class function App.GetIsInitialized: Boolean; static;
begin
  Result := Assigned(fMainForm);
end;

class constructor App.Create;
begin
  FSyncLock := TSyncObject.Create();

  FEnglishLettersRegex := TRegExpr.Create;
  FEnglishLettersRegex.ModifierI := True;
  FEnglishLettersRegex.Expression := '^[a-zA-Z0-9. \-_?]*$';

  FZoomFactor := 1.0;

  fSettings := TAppSettings.Create();
  fSettings.Load();
end;

class destructor App.Destroy;
begin
  FreeAndNil(fSettings);
  FreeAndNil(FEnglishLettersRegex);
  FreeAndNil(FSyncLock);
end;

class procedure App.Initialize(AMainForm: TForm);
begin
  if not IsInitialized then
  begin
    App.fMainForm := AMainForm;

    LoadLastProject();

{ TODO:
ZoomFactor = Settings.ZoomFactor;
LoadLastProject();

AutoSaveService = new AutoSaveService(AutoSaveProc);
AutoSaveService.Enabled = Settings.AutoSave;

UpdateRichTextEditorGlobals();
}
  end;
end;

/// <summary>
/// Shows an error message box
/// </summary>
class procedure App.ErrorBox(const Message: string);
begin
  MessageDlg('Error', Message, mtError, [mbOK], 0);
end;

/// <summary>
/// Shows a warning message box
/// </summary>
class procedure App.WarningBox(const Message: string);
begin
  MessageDlg('Warning', Message, mtWarning, [mbOK], 0);
end;

/// <summary>
/// Shows an information message box
/// </summary>
class procedure App.InfoBox(const Message: string);
begin
  MessageDlg('Information', Message, mtInformation, [mbOK], 0);
end;

/// <summary>
/// Shows a Yes/No question message box
/// </summary>
class function App.QuestionBox(const Message: string): Boolean;
begin
  Result :=
    MessageDlg(
      'Question',
      Message,
      mtConfirmation,
      [mbYes, mbNo],
      0
    ) = mrYes;
end;



class function App.ContainsWord(const Text: string; const WordToFind: string): Boolean;
var
  R: TRegExpr;
begin
  Result := False;

  if (Trim(Text) = '') or (Trim(WordToFind) = '') then
    Exit;

  R := TRegExpr.Create;
  try
    R.ModifierI := True; { IgnoreCase }
    { \b = word boundary, Escape the search term }
    R.Expression := '\b' + QuoteRegExprMetaChars(WordToFind) + '\b';
    Result := R.Exec(Text);
  finally
    R.Free;
  end;
end;

class function App.ContainsText(const Instance: string; const Value: string): Boolean;
begin
  if (Instance <> '') and (Trim(Value) <> '') then
    Result := Pos(UTF8LowerCase(Value), UTF8LowerCase(Instance)) > 0
  else
    Result := False;
end;

class function App.IsValidFileName(const Title: string; ShowMessage: Boolean): Boolean;
var
  i: Integer;
  c: Char;
  Invalid: set of Char;
  Msg: string;
begin
  Result := False;

  if Trim(Title) = '' then
    Exit;

  { Invalid filename chars (Windows style) }
  Invalid := ['\', '/', ':', '*', '?', '"', '<', '>', '|'];

  for i := 1 to Length(Title) do
  begin
    c := Title[i];
    if c in Invalid then
      Exit;
  end;

  if (Length(Title) > 0) and (Title[1] in ['0'..'9']) then
    Exit;

  { English letters policy - shared regex, thread-safe via lock }
  FSyncLock.Lock;
  try
    Result := (FEnglishLettersRegex <> nil) and FEnglishLettersRegex.Exec(Title);
  finally
    FSyncLock.UnLock;
  end;

  if (not Result) and ShowMessage then
  begin
    Msg := Format(SInvalidTitleErrorMessage, [Title]);
    ErrorBox(Msg);
    LogBox.AppendLine(Msg);
  end;
end;


class procedure App.CheckValidFileName(const Title: string);
var
  Msg: string;
begin
  Msg := Format(SInvalidTitleErrorMessage, [Title]); // αν δεν έχεις αυτό το const/var, βάλε απλό 'Invalid title'
  if not IsValidFileName(Title, False) then
    raise Exception.Create(Msg);
end;

class procedure App.CreateNewProject();
begin
  InfoBox('CreateNewProject');
end;

class procedure App.CloseProject();
var
  Title: string;
  Msg: string;
begin
  if Assigned(CurrentProject) then
  begin
    if Assigned(OnProjectClosed) then
      OnProjectClosed(nil);

    Title := CurrentProject.Title;

    CloseAllUi;
    CurrentProject := nil;

    Msg := 'Project closed: ''' + Title + '''.';
    LogBox.AppendLine(Msg);

    StopProjectStatsTimer;
  end;

end;

class procedure App.OpenProject();
var
  Dlg: TOpenDialog;
  FilePath: string;
begin
  Dlg := TOpenDialog.Create(nil);
  try
    Dlg.Filter := 'JSON files (*.json)|*.json';
    Dlg.Options := Dlg.Options + [ofPathMustExist, ofFileMustExist];
    Dlg.InitialDir := GetCurrentDir;

    if Dlg.Execute then
    begin
      FilePath := Dlg.FileName;

      if FileExists(FilePath) then
      begin
        CloseProject;
        LoadProject(ExtractFileDir(FilePath));
      end;
    end;
  finally
    Dlg.Free;
  end;

end;

procedure Test(const FolderPath: string);
var
  FilePath: string;
  JsonText: string;
  Parser: TJSONParser;
  Data: TJSONData;
  N: Integer;
begin
  FilePath := Sys.CombinePaths([FolderPath, 'Project.json']);
  JsonText := Sys.LoadFromFile(FilePath);

  Parser := TJSONParser.Create(JsonText,[]);
  Data := Parser.Parse();
  N := Data.Count;
end;

class procedure App.LoadProject(const FolderPath: string);
var
  Proj: TProject;
  Msg: string;
begin
  //Test(FolderPath);

  Proj := TProject.Create;
  try
    Proj.FolderPath := FolderPath;
    Proj.Load;

    Settings.LastProjectFolderPath := Proj.FolderPath;
    Settings.Save;

    CurrentProject := Proj;

    if Assigned(OnProjectOpened) then
      OnProjectOpened(nil);

    ShowSideBarPages;

    Msg := 'Project opened: ''' + Proj.Title + '''.';
    LogBox.AppendLine(Msg);

    StartProjectStatsTimer;
  except
    Proj.Free;
    CurrentProject := nil;
    raise;
  end;

end;

class procedure App.LoadLastProject();
var
  FolderPath: string;
begin
  if Assigned(Settings) then
  begin
    FolderPath := Settings.LastProjectFolderPath;

    if Settings.LoadLastProjectOnStartup
       and (Trim(FolderPath) <> '')
       and DirectoryExists(FolderPath) then
    begin
      CloseProject;
      LoadProject(FolderPath);
    end;
  end;

end;

class procedure App.StartProjectStatsTimer();
begin

end;

class procedure App.StopProjectStatsTimer();
begin

end;

class procedure App.DisplayFileExplorer(const FileOrFolderPath: string);
var
  P: TProcess;
  Path: string;
begin
  if not FileExists(FileOrFolderPath) and not DirectoryExists(FileOrFolderPath) then
    Exit;

  Path := ExpandFileName(FileOrFolderPath);

  P := TProcess.Create(nil);
  try
    {$IFDEF WINDOWS}
    P.Executable := 'explorer.exe';
    P.Parameters.Add('/select,');
    P.Parameters.Add(Path);
    {$ENDIF}

    {$IFDEF LINUX}
    // αν είναι φάκελος -> άνοιξε τον
    // αν είναι αρχείο -> άνοιξε τον φάκελο που τον περιέχει
    if FileExists(Path) then
      Path := ExtractFileDir(Path);

    P.Executable := 'xdg-open';
    P.Parameters.Add(Path);
    {$ENDIF}

    P.Options := [poNoConsole, poWaitOnExit];
    P.Execute;
  finally
    P.Free;
  end;
end;

class function App.ShowFolderDialog(var FolderPath: string): Boolean;
var
  D: TSelectDirectoryDialog;
begin
  Result := False;

  D := TSelectDirectoryDialog.Create(nil);
  try
    D.InitialDir := FolderPath;

    if D.Execute then
    begin
      if Trim(D.FileName) <> '' then
      begin
        FolderPath := D.FileName;
        Result := True;
      end;
    end;
  finally
    D.Free;
  end;

end;

class procedure App.ShowTranslator();
begin

end;

class procedure App.CloseAllUi();
begin
  SideBarPagerHandler.CloseAll();
  ContentPagerHandler.CloseAll();
end;

class procedure App.ShowSideBarPages();
begin
  SideBarPagerHandler.ShowPage(TfrCategoryList, TfrCategoryList.ClassName, nil);

  SideBarPagerHandler.ShowPage(TfrStoryList, TfrStoryList.ClassName, nil);

{       TfrCategoryList
var Page = SideBarPagerHandler.ShowPage(typeof(UC_StoryList), nameof(UC_StoryList), null);
TabControl Pager = Page.Parent as TabControl;
Pager.SelectTab(Pager.TabPages.Count - 1);
}
end;

class procedure App.ShowSettingsDialog();
begin

end;

class procedure App.ClearPageControl(APageControl: TPageControl);
begin
  while APageControl.PageCount > 0 do
    APageControl.Pages[0].Free;
end;

class procedure App.InitializeReadOnly(Grid: TDbGrid);
begin
  Grid.Options := Grid.Options - [dgEditing];
  Grid.ReadOnly := True;
end;

class procedure App.AddColumn(Grid: TDbGrid; const FieldName: string; const Title: string);
var
  Col: TColumn;
begin
  Col := Grid.Columns.Add();
  Col.FieldName := FieldName;
  if (Trim(Title) <> '') and (FieldName <> Title) then
     Col.Title.Caption := Title;
end;



end.

