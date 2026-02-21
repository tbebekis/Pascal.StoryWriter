unit o_StoryExporter;

{$mode delphi}

interface

uses
  Classes, SysUtils, Types,
  Process,
  Forms,
  Controls,
  Tripous,
  o_ExportOptions,

  o_Entities; // TStory, TChapter, TScene, TSWComponent, etc.

type

  { TStoryExporter }

  TStoryExporter = class
  private
    FFolderPath: string;
    FStory: TStory;
    FOptions: TExportOptions;
    FSB: TStrBuilder;

  private
    { helpers }
    class function FindSoffice: string; static;
    class function LibreOfficeExists: Boolean; static;

    class function ToLines(const Text: string): TStringDynArray; static;
    function GetHtmlText(const PlainText: string): string;

    function EscapeHtmlText(const S: string): string;

    { export }
    procedure ExportToText(InGreek: Boolean);
    function ExportToHtml(InGreek: Boolean): string;

    procedure ExportStorySynopsis;
    procedure ExportSceneSynopsis;

    procedure ExportToOdt(const HtmlFilePath: string; const TargetFormat: string = 'odt';
      TimeoutMsecs: Integer = 300000);

    procedure ExportComponentsAsSingleFile;
    procedure ExportForPreEditScenes;
    procedure ExportPreEditChapters;

  public
    constructor Create(AStory: TStory; AOptions: TExportOptions);
    procedure Execute;

    class procedure Export(AStory: TStory);
  end;

implementation

uses
  o_App
  ,Tripous.Logs
  ,f_ExportDialog
  ;

{ TStoryExporter }

constructor TStoryExporter.Create(AStory: TStory; AOptions: TExportOptions);
begin
  inherited Create;
  FStory := AStory;
  FOptions := AOptions;
end;

class function TStoryExporter.FindSoffice: string;
var
  EnvPath: string;
  Parts: TStringDynArray;
  Dir: string;
  Exe: string;
  I: Integer;
  Candidates: array[0..1] of string;
begin
  Result := '';

  EnvPath := GetEnvironmentVariable('PATH');

  if EnvPath <> '' then
  begin
    Parts := EnvPath.Split([PathSeparator]);
    for I := 0 to High(Parts) do
    begin
      Dir := Parts[I];

      Exe := Sys.CombinePath(Dir, 'soffice.exe');
      if FileExists(Exe) then Exit(Exe);

      Exe := Sys.CombinePath(Dir, 'soffice');
      if FileExists(Exe) then Exit(Exe);

      Exe := Sys.CombinePath(Dir, 'libreoffice');
      if FileExists(Exe) then Exit(Exe);
    end;
  end;

  Candidates[0] := 'C:\Program Files\LibreOffice\program\soffice.exe';
  Candidates[1] := 'C:\Program Files (x86)\LibreOffice\program\soffice.exe';

  for I := Low(Candidates) to High(Candidates) do
    if FileExists(Candidates[I]) then
      Exit(Candidates[I]);
end;

class function TStoryExporter.LibreOfficeExists: Boolean;
begin
  Result := FindSoffice <> '';
end;

class function TStoryExporter.ToLines(const Text: string): TStringDynArray;
var
  S: string;
begin
  // Normalize all line endings to #10 then split while preserving empty lines
  S := StringReplace(Text, #13#10, #10, [rfReplaceAll]);
  S := StringReplace(S, #13, #10, [rfReplaceAll]);
  Result := S.Split([#10]);
end;

function TStoryExporter.EscapeHtmlText(const S: string): string;
begin
  // Minimal correct HTML escaping for text nodes
  Result := S;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
end;

function TStoryExporter.GetHtmlText(const PlainText: string): string;
var
  Lines: TStringDynArray;
  I: Integer;
  Line: string;
  SBLocal: TStrBuilder;
begin
  Result := PlainText;
  if Trim(Result) = '' then
    Exit;

  Lines := ToLines(Result);
  SBLocal := TStrBuilder.Create;
  try
    for I := 0 to High(Lines) do
    begin
      Line := Trim(Lines[I]);
      if Line = '' then
        Line := '&nbsp;'
      else
        Line := EscapeHtmlText(Line);

      SBLocal.Append('<p>');
      SBLocal.Append(Line);
      SBLocal.AppendLine('</p>');
    end;

    Result := SBLocal.ToUtf8String;
  finally
    SBLocal.Free;
  end;
end;

procedure TStoryExporter.ExportToText(InGreek: Boolean);
var
  Item: TCollectionItem;
  Item2: TCollectionItem;
  Chapter: TChapter;
  Scene: TScene;
  Text: string;
  FileName: string;
  FilePath: string;

  function GetChapterTitle(AChapter: TChapter): string;
  begin
    Result := '';

    if etoBullet in FOptions.ChapterTitle then
      Result := Result + '●';

    if etoWord in FOptions.ChapterTitle then
    begin
      if Result = '' then
        Result := 'Chapter'
      else
        Result := Result + ' Chapter';
    end;

    if etoNumber in FOptions.ChapterTitle then
    begin
      if Result = '' then
        Result := IntToStr(AChapter.OrderIndex + 1)
      else
        Result := Result + ' ' + IntToStr(AChapter.OrderIndex + 1);
    end;

    if etoTitle in FOptions.ChapterTitle then
    begin
      if etoNumber in FOptions.ChapterTitle then
        Result := Result + '. ' + AChapter.Title
      else if etoWord in FOptions.ChapterTitle then
        Result := Result + ': ' + AChapter.Title
      else
        Result := Result + AChapter.Title;
    end;
  end;

  function GetSceneTitle(AScene: TScene): string;
  begin
    Result := '';

    if etoBullet in FOptions.SceneTitle then
      Result := Result + '●';

    if etoWord in FOptions.SceneTitle then
    begin
      if Result = '' then
        Result := 'Scene'
      else
        Result := Result + ' Scene';
    end;

    if etoNumber in FOptions.SceneTitle then
    begin
      if Result = '' then
        Result := IntToStr(AScene.OrderIndex + 1)
      else
        Result := Result + ' ' + IntToStr(AScene.OrderIndex + 1);
    end;

    if etoTitle in FOptions.SceneTitle then
    begin
      if etoNumber in FOptions.SceneTitle then
        Result := Result + '. ' + AScene.Title
      else if etoWord in FOptions.SceneTitle then
        Result := Result + ': ' + AScene.Title
      else
        Result := Result + AScene.Title;
    end;
  end;

begin
  // Application.ProcessMessages; // per request: keep as comment

  FreeAndNil(FSB);
  FSB := TStrBuilder.Create;

  for Item in FStory.ChapterList do
  begin
    Chapter := TChapter(Item);
    if FOptions.ChapterTitle <> [] then
    begin
      if Chapter.OrderIndex > 0 then
      begin
        FSB.AppendLine;
        FSB.AppendLine;
      end;
      FSB.AppendLine(GetChapterTitle(Chapter));
    end;

    for Item2 in Chapter.SceneList do
    begin
      Scene := TScene(Item2);
      if FOptions.SceneTitle <> [] then
      begin
        if Scene.OrderIndex > 0 then
          FSB.AppendLine;
        FSB.AppendLine(GetSceneTitle(Scene));
      end;

      if InGreek then
        Text := Scene.Text
      else
        Text := Scene.TextEn;

      if Trim(Text) <> '' then
        FSB.AppendLine(Text);

      if (FOptions.SceneTitle = []) and (not Scene.IsLast) then
        FSB.AppendLine('***');
    end;
  end;

  Text := FSB.ToUtf8String;

  if InGreek then
    FileName := FStory.Title + '.txt'
  else
    FileName := FStory.Title + 'En.txt';

  FilePath := Sys.CombinePath(FFolderPath, FileName);

  Sys.WriteUtf8TextFile(FilePath, Text, False);
  Sys.WaitForFileAvailable(FilePath);
end;

function TStoryExporter.ExportToHtml(InGreek: Boolean): string;
var
  Item: TCollectionItem;
  Item2: TCollectionItem;
  Chapter: TChapter;
  Scene: TScene;
  ChapterTitle: string;
  SceneTitle: string;
  Text: string;
  HtmlText: string;
  FileName: string;
  FilePath: string;

  function HasNumberAndTitle(const Opts: TExportTitleOptions): Boolean;
  begin
    Result := (etoNumber in Opts) and (etoTitle in Opts);
  end;

begin
  // Application.ProcessMessages; // per request: keep as comment

  FreeAndNil(FSB);
  FSB := TStrBuilder.Create;

  for Item in FStory.ChapterList do
  begin
    Chapter := TChapter(Item);
    if FOptions.ChapterTitle <> [] then
    begin
      if HasNumberAndTitle(FOptions.ChapterTitle) then
        ChapterTitle := Chapter.DisplayTitleInStory
      else
        ChapterTitle := Chapter.Title;

      FSB.Append('<h1>');
      FSB.Append(EscapeHtmlText(ChapterTitle));
      FSB.AppendLine('</h1>');
      FSB.AppendLine;
    end;

    for Item2 in Chapter.SceneList do
    begin
      Scene := TScene(Item2);
      if FOptions.SceneTitle <> [] then
      begin
        if HasNumberAndTitle(FOptions.SceneTitle) then
          SceneTitle := Scene.DisplayTitleInStory
        else
          SceneTitle := Scene.Title;

        FSB.Append('<h2>');
        FSB.Append(EscapeHtmlText(SceneTitle));
        FSB.AppendLine('</h2>');
        FSB.AppendLine;
      end;

      if InGreek then
        Text := Scene.Text
      else
        Text := Scene.TextEn;

      Text := GetHtmlText(Text);
      if Trim(Text) <> '' then
        FSB.AppendLine(Text);

      if (FOptions.SceneTitle = []) and (not Scene.IsLast) then
        FSB.AppendLine('***');
    end;
  end;

  HtmlText :=
    '<!DOCTYPE html>' + LineEnding +
    '<html>' + LineEnding +
    '<head>' + LineEnding +
    '<meta charset="utf-8">' + LineEnding +
    '<title>Page Title</title>' + LineEnding +
    '</head>' + LineEnding +
    '<body>' + LineEnding +
    FSB.ToUtf8String +
    LineEnding + '</body>' + LineEnding + '</html>' + LineEnding;

  if InGreek then
    FileName := FStory.Title + '.html'
  else
    FileName := FStory.Title + 'En.html';

  FilePath := Sys.CombinePath(FFolderPath, FileName);

  Sys.WriteUtf8TextFile(FilePath, HtmlText, False);
  Sys.WaitForFileAvailable(FilePath);

  Result := FilePath;
end;

procedure TStoryExporter.ExportStorySynopsis;
var
  Item: TCollectionItem;
  Chapter: TChapter;
  Title: string;
  Text: string;
  FilePath: string;
begin
  // Application.ProcessMessages; // per request: keep as comment

  FreeAndNil(FSB);
  FSB := TStrBuilder.Create;

  Title := '● STORY: ' + FStory.Title;
  FSB.AppendLine(Title);

  Text := Trim(FStory.Synopsis);
  if Text <> '' then
    FSB.AppendLine(Text);

  for Item in FStory.ChapterList do
  begin
    Chapter := TChapter(Item);
    FSB.AppendLine;
    Title := '● CHAPTER ' + IntToStr(Chapter.OrderIndex + 1) + ': ' + Chapter.Title;
    FSB.AppendLine(Title);

    Text := Trim(Chapter.Synopsis);
    if Text <> '' then
      FSB.AppendLine(Text);
  end;

  FSB.AppendLine;
  FSB.AppendLine('● THE END');

  Text := FSB.ToUtf8String;

  FilePath := Sys.CombinePath(FFolderPath, 'Story Synopsis - ' + FStory.Title + '.txt');
  Sys.WriteUtf8TextFile(FilePath, Text, False);
  Sys.WaitForFileAvailable(FilePath);
end;

procedure TStoryExporter.ExportSceneSynopsis;
var
  Item: TCollectionItem;
  Item2: TCollectionItem;
  Chapter: TChapter;
  Scene: TScene;
  Title: string;
  Text: string;
  FilePath: string;
begin
  // Application.ProcessMessages; // per request: keep as comment

  FreeAndNil(FSB);
  FSB := TStrBuilder.Create;

  Title := '● STORY: ' + FStory.Title;
  FSB.AppendLine(Title);

  Text := Trim(FStory.Synopsis);
  if Text <> '' then
    FSB.AppendLine(Text);

  for Item in FStory.ChapterList do
  begin
    Chapter := TChapter(Item);
    FSB.AppendLine;
    Title := '● CHAPTER ' + IntToStr(Chapter.OrderIndex + 1) + ': ' + Chapter.Title;
    FSB.AppendLine(Title);

    for Item2 in Chapter.SceneList do
    begin
      Scene := TScene(Item2);
      FSB.AppendLine;
      Title := '● SCENE ' + IntToStr(Chapter.OrderIndex + 1) + '.' + IntToStr(Scene.OrderIndex + 1) + ': ' + Scene.Title;
      FSB.AppendLine(Title);

      Text := Trim(Scene.Synopsis);
      if Text <> '' then
        FSB.AppendLine(Text);
    end;
  end;

  FSB.AppendLine;
  FSB.AppendLine('● THE END');

  Text := FSB.ToUtf8String;

  FilePath := Sys.CombinePath(FFolderPath, 'Scene Synopsis - ' + FStory.Title + '.txt');
  Sys.WriteUtf8TextFile(FilePath, Text, False);
  Sys.WaitForFileAvailable(FilePath);
end;

procedure TStoryExporter.ExportToOdt(const HtmlFilePath: string; const TargetFormat: string; TimeoutMsecs: Integer);
var
  SOfficePath: string;
  P: TProcess;
  StartTick: QWord;
  OutFilePath: string;

  function TimedOut: Boolean;
  begin
    Result := (TimeoutMsecs > 0) and ((GetTickCount64 - StartTick) > QWord(TimeoutMsecs));
  end;

begin
  // Application.ProcessMessages; // per request: keep as comment

  SOfficePath := FindSoffice;
  if SOfficePath = '' then
    raise Exception.Create('Cannot convert. LibreOffice (soffice) not found.');

  P := TProcess.Create(nil);
  try
    P.Executable := SOfficePath;

    // IMPORTANT: use Parameters (not a single Arguments string) for safer quoting.
    P.Parameters.Add('--headless');
    P.Parameters.Add('--convert-to');
    P.Parameters.Add(TargetFormat);
    P.Parameters.Add('--outdir');
    P.Parameters.Add(FFolderPath);
    P.Parameters.Add(HtmlFilePath);

    P.Options := [poNoConsole, poWaitOnExit];

    StartTick := GetTickCount64;
    P.Execute;

    // poWaitOnExit waits, but we still keep timeout logic in case platform behaves oddly.
    while P.Running do
    begin
      if TimedOut then
      begin
        try
          P.Terminate(0);
        except
        end;
        raise Exception.CreateFmt('Cannot convert source file %s to %s. Timeout of %d ms exceeded.',
          [HtmlFilePath, TargetFormat, TimeoutMsecs]);
      end;
      Sleep(50);
    end;

  finally
    P.Free;
  end;

  OutFilePath := Sys.CombinePath(FFolderPath, FStory.Title + '.odt');
  Sys.WaitForFileAvailable(OutFilePath);
end;

procedure TStoryExporter.ExportComponentsAsSingleFile;
var
  Item: TCollectionItem;
  C: TSWComponent;
  Title: string;
  Aliases: string;
  Tags: string;
  Text: string;
  FilePath: string;
begin
  // Application.ProcessMessages; // per request: keep as comment

  FreeAndNil(FSB);
  FSB := TStrBuilder.Create;

  // App.CurrentProject.ComponentList is TSWComponentCollection (iterable via for..in if enumerator exists)
  // If your collection has no enumerator, replace with for I := 0..Count-1.
  for Item in App.CurrentProject.ComponentList do
  begin
    C := TSWComponent(Item);
    Title := '● COMPONENT: ' + C.Title;
    FSB.AppendLine(Title);

    Aliases := 'ALIASES: ' + C.Aliases;
    FSB.AppendLine(Aliases);

    Tags := 'TAGS: ' + C.Tags;
    FSB.AppendLine(Tags);

    FSB.AppendLine;
    FSB.AppendLine(C.Text);
    FSB.AppendLine;
    FSB.AppendLine;
  end;

  Text := FSB.ToUtf8String;
  FilePath := Sys.CombinePath(FFolderPath, 'Components.txt');

  Sys.WriteUtf8TextFile(FilePath, Text, False);
  Sys.WaitForFileAvailable(FilePath);
end;

procedure TStoryExporter.ExportForPreEditScenes;
var
  Item: TCollectionItem;
  Item2: TCollectionItem;
  Chapter: TChapter;
  Scene: TScene;
  Text: string;
  FileName: string;
  PreEditFolderPath: string;
  Folder: string;
  FilePath: string;
begin
  // Application.ProcessMessages; // per request: keep as comment

  PreEditFolderPath := Sys.CombinePath(FFolderPath, 'PreEdit_Scenes');
  if not Sys.FolderExists(PreEditFolderPath) then
    Sys.CreateFolders(PreEditFolderPath);

  if elGreek in FOptions.Language then
  begin
    Folder := Sys.CombinePath(PreEditFolderPath, 'Gr');
    if not Sys.FolderExists(Folder) then
      Sys.CreateFolders(Folder);

    for Item in FStory.ChapterList do
    begin
      Chapter := TChapter(Item);
      for Item2 in Chapter.SceneList do
      begin
        Scene := TScene(Item2);
        Text := Scene.Text;
        FileName := IntToStr(Chapter.OrderIndex + 1) + '.' + IntToStr(Scene.OrderIndex + 1) + ' ' + Scene.Title + '.txt';
        FilePath := Sys.CombinePath(Folder, FileName);

        Sys.WriteUtf8TextFile(FilePath, Text, False);
        Sys.WaitForFileAvailable(FilePath);
      end;
    end;
  end;

  if elEnglish in FOptions.Language then
  begin
    Folder := Sys.CombinePath(PreEditFolderPath, 'En');
    if not Sys.FolderExists(Folder) then
      Sys.CreateFolders(Folder);

    for Item in FStory.ChapterList do
    begin
      Chapter := TChapter(Item);
      for Item2 in Chapter.SceneList do
      begin
        Scene := TScene(Item2);
        Text := Scene.TextEn;
        FileName := IntToStr(Chapter.OrderIndex + 1) + '.' + IntToStr(Scene.OrderIndex + 1) + ' ' + Scene.Title + '.txt';
        FilePath := Sys.CombinePath(Folder, FileName);

        Sys.WriteUtf8TextFile(FilePath, Text, False);
        Sys.WaitForFileAvailable(FilePath);
      end;
    end;
  end;
end;

procedure TStoryExporter.ExportPreEditChapters;
var
  Item: TCollectionItem;
  Item2: TCollectionItem;
  Chapter: TChapter;
  Scene: TScene;
  SBLocal: TStrBuilder;
  Text: string;
  FileName: string;
  PreEditFolderPath: string;
  FilePath: string;
begin
  // Application.ProcessMessages; // per request: keep as comment

  PreEditFolderPath := Sys.CombinePath(FFolderPath, 'PreEdit_Chapters');
  if not Sys.FolderExists(PreEditFolderPath) then
    Sys.CreateFolders(PreEditFolderPath);

  SBLocal := TStrBuilder.Create;
  try
    for Item in FStory.ChapterList do
    begin
      Chapter := TChapter(Item);
      SBLocal.Clear;
      SBLocal.AppendLine('● CHAPTER ' + IntToStr(Chapter.OrderIndex + 1) + ': ' + Chapter.Title);
      SBLocal.AppendLine;

      for Item2 in Chapter.SceneList do
      begin
        Scene := TScene(Item2);
        SBLocal.AppendLine('● SCENE ' + IntToStr(Scene.OrderIndex + 1) + ': ' + Scene.Title);
        Text := Scene.TextEn; // matches your C# (TextEn)
        SBLocal.AppendLine(Text);
      end;

      FileName := IntToStr(Chapter.OrderIndex + 1) + '. ' + Chapter.Title + '.txt';
      FilePath := Sys.CombinePath(PreEditFolderPath, FileName);

      Text := SBLocal.ToUtf8String;
      Sys.WriteUtf8TextFile(FilePath, Text, False);
      Sys.WaitForFileAvailable(FilePath);
    end;
  finally
    SBLocal.Free;
  end;
end;

procedure TStoryExporter.Execute;
var
  DT: string;
  HtmlFilePath: string;
  HtmlFilePathEn: string;
begin
  if (FStory = nil) or (FOptions = nil) then
    Exit;

  FFolderPath := Sys.CombinePath(FStory.FolderPath, 'Export');
  if not Sys.FolderExists(FFolderPath) then
    Sys.CreateFolders(FFolderPath);

  DT := Sys.DateTimeToFileName(Now, False);
  FFolderPath := Sys.CombinePath(FFolderPath, DT);
  if not Sys.FolderExists(FFolderPath) then
    Sys.CreateFolders(FFolderPath);

  // text
  if efTXT in FOptions.Format then
  begin
    if elGreek in FOptions.Language then
      ExportToText(True);
    if elEnglish in FOptions.Language then
      ExportToText(False);
  end;

  if FOptions.SingleComponentText then
    ExportComponentsAsSingleFile;

  if FOptions.PreEditScenes then
    ExportForPreEditScenes;

  if FOptions.PreEditChapters then
    ExportPreEditChapters;

  if esSynopsis in FOptions.Source then
  begin
    ExportStorySynopsis;
    ExportSceneSynopsis;
  end;

  // html -> odt
  if efODT in FOptions.Format then
  begin
    HtmlFilePath := '';
    HtmlFilePathEn := '';

    if elGreek in FOptions.Language then
      HtmlFilePath := ExportToHtml(True);

    if elEnglish in FOptions.Language then
      HtmlFilePathEn := ExportToHtml(False);

    if not LibreOfficeExists then
    begin
      App.ErrorBox('LibreOffice is not installed. Please install it and try again.');
      LogBox.AppendLine('LibreOffice is not installed. Please install it and try again.');

      App.DisplayFileExplorer(FFolderPath);
      Exit;
    end;

    if Trim(HtmlFilePath) <> '' then
      ExportToOdt(HtmlFilePath);

    if Trim(HtmlFilePathEn) <> '' then
      ExportToOdt(HtmlFilePathEn);
  end;

  App.DisplayFileExplorer(FFolderPath);
end;

class procedure TStoryExporter.Export(AStory: TStory);
var
  Options : TExportOptions;
  Message : string;
  Exporter : TStoryExporter;
begin
  Options := TExportOptions.Create();
  try
    if TExportDialog.ShowDialog(Options) then
    begin
      Message := 'Exporting... Please Wait...';
      LogBox.AppendLine(Message);

      Screen.Cursor := crHourGlass;
      Application.ProcessMessages;
      Exporter := TStoryExporter.Create(AStory, Options);
      try
        Exporter.Execute();

        LogBox.AppendLine('DONE.');
      finally
        Exporter.Free;
        Screen.Cursor := crDefault;
      end;
    end;
  finally
    Options.Free();
  end;

end;

end.
