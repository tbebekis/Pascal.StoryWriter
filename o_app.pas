unit o_App;

{$MODE DELPHI}{$H+}
{$modeswitch nestedprocvars}

interface

uses
  Classes
  ,SysUtils
  , Forms
  , Controls
  ,ComCtrls
  ,ExtCtrls
  ,Dialogs
  , DBCtrls
  , DBGrids
  //,Regex
  ,RegExpr

  ,SynEdit

  ,Tripous
  ,o_PageHandler

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
    class var fLastGlobalSearchTerm: string;
    class var fLastGlobalSearchTermWholeWord: Boolean;

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
    class procedure ShowSideBarPages();
    class procedure CloseAllUi();

    class procedure ShowSettingsDialog();
    class function  ShowFolderDialog(var FolderPath: string): Boolean;
    class procedure DisplayFileExplorer(const FileOrFolderPath: string);
    class procedure ClearPageControl(APageControl: TPageControl);

    class function  ShowLinkItemPage(LinkItem: TLinkItem): TTabSheet;
    class procedure UpdateLinkItemUi(LinkItem: TLinkItem; Panel: TPanel; Editor: TSynEdit);
    class procedure ShowItemInListPage(LinkItem: TLinkItem);

    class procedure UpdateComponentListNote();

    // ● event triggers
    class procedure SetGlobalSearchTerm(const Term: string);
    class procedure PerformCategoryListChanged(Sender: TObject);
    class procedure PerformTagListChanged(Sender: TObject);

    // ● Grid
    class procedure InitializeReadOnly(Grid: TDbGrid);
    class procedure AddColumn(Grid: TDbGrid; const FieldName: string; const Title: string = '');
    class procedure AdjustGridColumns(Grid: TDBGrid; Width: Integer = 100);

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
    class procedure ShowTranslator();
    class procedure LogLine(const Text: string);

    // ● properties
    class property IsInitialized: Boolean read GetIsInitialized;
    class property Settings: TAppSettings read fSettings;

    class property MainForm: TForm read fMainForm;
    class property SideBarPagerHandler : TPagerHandler read fSideBarPagerHandler write fSideBarPagerHandler;
    class property ContentPagerHandler : TPagerHandler read fContentPagerHandler write fContentPagerHandler;

    class property CurrentProject: TProject read fProject write fProject;
    class property ZoomFactor: Double read FZoomFactor write FZoomFactor;

    class property LastGlobalSearchTerm: string read fLastGlobalSearchTerm write fLastGlobalSearchTerm;
    class property LastGlobalSearchTermWholeWord: Boolean read fLastGlobalSearchTermWholeWord write fLastGlobalSearchTermWholeWord;

  end;

implementation

uses
   LazUTF8
  ,Process
  ,System.UITypes
  ,jsonparser
  ,fpjson

  ,Tripous.List.Helpers
  ,Tripous.Logs
  ,Tripous.Broadcaster

  ,o_Consts
  ,o_TextStats

  ,f_AppSettingsDialog
  ,f_ProjectEditDialog

  //,f_MainForm
  ,fr_CategoryList
  ,fr_TagList
  ,fr_ComponentList
  ,fr_Search
  ,fr_QuickView
  ,fr_NoteList
  ,fr_TempText
  ,fr_Component
  ,fr_Note
  ,fr_Story
  ,fr_StoryList
  ,fr_Chapter
  ,fr_Scene
  ;



{ App }


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
var
  Project: TProject;
  Message: string;
begin
  Project := TProject.Create();
  if not TProjectEditDialog.ShowDialog(Project) then
  begin
    Project.Free();
    Exit;
  end;

  CloseProject();

  Project.Save();

  App.Settings.LastProjectFolderPath := Project.FolderPath;
  App.Settings.Save();

  CurrentProject := Project;
  Broadcaster.Broadcast(SProjectOpened, nil);

  Message := Format('New Project created: %s', [Project.Title]);
  LogBox.AppendLine(Message);

end;

class procedure App.CloseProject();
var
  Title: string;
  Msg: string;
begin
  if Assigned(CurrentProject) then
  begin
    StopProjectStatsTimer;

    Broadcaster.Broadcast(SProjectClosed, nil);

    Title := CurrentProject.Title;

    CloseAllUi;
    CurrentProject.Free();
    CurrentProject := nil;

    Msg := 'Project closed: ''' + Title + '''.';
    LogBox.AppendLine(Msg);
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

class procedure App.LoadProject(const FolderPath: string);
var
  Proj: TProject;
  Msg: string;
begin
  Proj := TProject.Create;
  try
    Proj.FolderPath := FolderPath;
    Proj.Load;

    Settings.LastProjectFolderPath := Proj.FolderPath;
    Settings.Save;

    CurrentProject := Proj;

    Broadcaster.Broadcast(SProjectOpened, nil);

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
  TextMetrics.Active := True;
end;

class procedure App.StopProjectStatsTimer();
begin
  TextMetrics.Active := False;
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
  // TODO: App.ShowTranslator();
end;

class procedure App.LogLine(const Text: string);
begin
  LogBox.AppendLine(Text);
end;

class procedure App.CloseAllUi();
begin
  SideBarPagerHandler.CloseAll();
  ContentPagerHandler.CloseAll();
end;

class procedure App.ShowSideBarPages();
begin
  SideBarPagerHandler.ShowPage(TfrCategoryList, TfrCategoryList.ClassName, nil);
  SideBarPagerHandler.ShowPage(TfrTagList, TfrTagList.ClassName, nil);
  SideBarPagerHandler.ShowPage(TfrComponentList, TfrComponentList.ClassName, nil);
  SideBarPagerHandler.ShowPage(TfrSearch, TfrSearch.ClassName, nil);
  SideBarPagerHandler.ShowPage(TfrQuickView, TfrQuickView.ClassName, nil);
  SideBarPagerHandler.ShowPage(TfrNoteList, TfrNoteList.ClassName, nil);
  SideBarPagerHandler.ShowPage(TfrTempText, TfrTempText.ClassName, nil);

  SideBarPagerHandler.ShowPage(TfrStoryList, TfrStoryList.ClassName, nil);
end;

class procedure App.ShowSettingsDialog();
var
  Message: string;
begin
  Message :=
    'This will close all opened UI.' + LineEnding +
    'Any unsaved changes will be lost.' + LineEnding +
    'Do you want to continue?';

  if not App.QuestionBox(Message) then
    Exit;

  App.CloseProject;
  Application.ProcessMessages;

  if TAppSettingsDialog.ShowDialog() then
  begin
    // nothing
  end;

  App.LoadLastProject();
end;

class procedure App.ClearPageControl(APageControl: TPageControl);
begin
  while APageControl.PageCount > 0 do
    APageControl.Pages[0].Free;
end;

class function App.ShowLinkItemPage(LinkItem: TLinkItem): TTabSheet;
var
  Comp: TSWComponent;
  Note: TNote;
  Story: TStory;
  Chapter: TChapter;
  Scene: TScene;
  frScene: TfrScene;
begin
  Result := nil;

  if (not Assigned(LinkItem)) or (not Assigned(LinkItem.Item)) or (not Assigned(CurrentProject)) then
    Exit;

  case LinkItem.ItemType of
    itComponent:
      begin
        Comp := LinkItem.Item as TSWComponent;
        Result := App.ContentPagerHandler.ShowPage(TfrComponent, Comp.Id, Comp);
      end;
    itNote:
      begin
        Note :=  LinkItem.Item as TNote;
        Result := App.ContentPagerHandler.ShowPage(TfrNote, Note.Id, Note);
      end;
    itStory:
      begin
        Story := LinkItem.Item as TStory;
        Result := App.ContentPagerHandler.ShowPage(TfrStory, Story.Id, Story);
      end;
    itChapter:
      begin
        Chapter := LinkItem.Item as TChapter;
        Result := App.ContentPagerHandler.ShowPage(TfrChapter, Chapter.Id, Chapter);
      end;
    itScene:
      begin
        Scene := LinkItem.Item as TScene;
        if (Assigned(Scene)) then
        begin
          Result := App.ContentPagerHandler.ShowPage(TfrScene, Scene.Id, Scene);
          frScene := TfrScene(Result.Tag);
          frScene.ShowTabPage(LinkItem.Place);
        end;
      end;
  end;
end;

class procedure App.UpdateLinkItemUi(LinkItem: TLinkItem; Panel: TPanel;  Editor: TSynEdit);
var
  Comp: TSWComponent;
  Note: TNote;
  Chapter: TChapter;
  Scene: TScene;
begin
  if (not Assigned(LinkItem)) or (not Assigned(LinkItem.Item)) or (not Assigned(CurrentProject)) then
    Exit;

  case LinkItem.ItemType of
    itComponent:
      begin
        Comp := LinkItem.Item as TSWComponent;
        Panel.Caption := Format('Component: %s', [Comp.DisplayTitleInProject]);
        Editor.Text := Comp.Text;
      end;
    itChapter:
      begin
        Chapter := LinkItem.Item as TChapter;
        Panel.Caption := Format('Chapter: %s', [Chapter.DisplayTitleInProject]);
        Editor.Text := Chapter.Synopsis;
      end;
    itScene:
      begin
        Scene := LinkItem.Item as TScene;
        case LinkItem.Place of
          lpSynopsis:
            begin
              Panel.Caption := Format('Scene Synopsis: %s', [Scene.DisplayTitleInProject]);
              Editor.Text := Scene.Synopsis;
            end;
          lpTimeline:
            begin
              Panel.Caption := Format('Scene Timeline: %s', [Scene.DisplayTitleInProject]);
              Editor.Text := Scene.Timeline;
            end;
          lpText:
            begin
              Panel.Caption := Format('Scene: %s', [Scene.DisplayTitleInProject]);
              Editor.Text := Scene.Text;
            end;
        end;
      end;
    itNote:
      begin
        Note :=  LinkItem.Item as TNote;
        Panel.Caption := Format('Note: %s', [Note.DisplayTitleInProject]);
        Editor.Text := Note.Text;
      end;
  end;

end;

class procedure App.ShowItemInListPage(LinkItem: TLinkItem);
var
  Item: TBaseItem;
  TabPage : TTabSheet;
  frComponentList: TfrComponentList;
  frNoteList: TfrNoteList;
  frStoryList: TfrStoryList;
begin
  Item := LinkItem.Item;
  if Item is TSWComponent then
  begin
    TabPage := App.SideBarPagerHandler.FindTabPage(TfrComponentList.ClassName);
    if Assigned(TabPage) and (TabPage.Tag > 0) then
    begin
      frComponentList := TfrComponentList(TabPage.Tag);
      if frComponentList.ShowItemInList(Item as TSWComponent) then
        SideBarPagerHandler.ShowPage(TfrComponentList, TfrComponentList.ClassName, nil);
    end;
  end else if Item is TNote then
  begin
    TabPage := App.SideBarPagerHandler.FindTabPage(TfrNoteList.ClassName);
    if Assigned(TabPage) and (TabPage.Tag > 0) then
    begin
      frNoteList := TfrNoteList(TabPage.Tag);
      if frNoteList.ShowItemInList(Item as TNote) then
        SideBarPagerHandler.ShowPage(TfrNoteList, TfrNoteList.ClassName, nil);
    end;
  end else if (Item is TStory) or (Item is TChapter) or (Item is TScene) then
  begin
    TabPage := App.SideBarPagerHandler.FindTabPage(TfrStoryList.ClassName);
    if Assigned(TabPage) and (TabPage.Tag > 0) then
    begin
      frStoryList := TfrStoryList(TabPage.Tag);
      if frStoryList.ShowItemInList(Item as TBaseItem) then
        SideBarPagerHandler.ShowPage(TfrStoryList, TfrStoryList.ClassName, nil);
    end;
  end;
end;

{ There is a standard Note entry, called "Component List" which displays a list of components.
  This method updates the text of that note. }
class procedure App.UpdateComponentListNote();
  //------------------------------------
  function FindNoteByName(Item: TObject): Boolean;
  begin
    Result := AnsiSameText(TNote(Item).Title, 'Component List');
  end;
  //------------------------------------
var
  Note: TNote;
  ComponentText: string;
begin
  if not Assigned(CurrentProject) then
    Exit;

  Note := CurrentProject.NoteList.FirstOrDefault(FindNoteByName) as TNote;
  if not Assigned(Note) then
    Exit;

  ComponentText := CurrentProject.GetComponentListText();
  Note.Text := ComponentText;
  Note.Save();
end;

class procedure App.SetGlobalSearchTerm(const Term: string);
begin
  SideBarPagerHandler.ShowPage(TfrSearch, TfrSearch.ClassName, nil);
  Broadcaster.Broadcast(TBroadcasterTextArgs.Create(SSearchTermIsSet, Term, nil), True);
end;

class procedure App.PerformCategoryListChanged(Sender: TObject);
begin
  Broadcaster.Broadcast(SCategoryListChanged, Sender);
end;

class procedure App.PerformTagListChanged(Sender: TObject);
begin
  Broadcaster.Broadcast(STagListChanged, Sender);
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

class procedure App.AdjustGridColumns(Grid: TDBGrid; Width: Integer);
var
  i : Integer;
begin
  for i := 0 to Grid.Columns.Count-1 do
    Grid.Columns[i].Width := Width;
end;


end.

