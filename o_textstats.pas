unit o_TextStats;

{$mode DELPHI}{$H+}

interface

uses
  Classes, SysUtils, ExtCtrls;

type

  { TTextStats }

  TTextStats = class
  public
    WordCount: Integer;
    CharCount: Integer;
    CharCountNoSpaces: Integer;
    LineCount: Integer;
    ParagraphCount: Integer;
    EstimatedPages: Double;

    procedure Reset();
  end;

  { TextMetrics }
  TextMetrics = class
  private
    class var fWordsPerPage: Integer;
    class var fTimerInterval: Integer;
    class var FActive: Boolean;
    class var FTimer: TTimer;

    class procedure SetActive(AValue: Boolean); static;


    class procedure AccumulateGlobal; static;
    class procedure AccumulateGlobalEn; static;

    { triggered only when Active := True, by an internal TTimer.
      Accumulates statistics for TScene.Text and TScene.TextEn }
    class procedure AccumulateGlobalAll; static;
  public
    { construction }
    class constructor Create();
    class destructor Destroy();

    { streaming accumulator: does NOT allocate, just scans }
    class procedure AccumulateStats(Stats: TTextStats; const Text: string); static;
    class procedure FinalizeStats(Stats: TTextStats); static;

    { starts/stops the internal timer }
    class property Active: Boolean read FActive write SetActive;

    { global - accumulates all stats from TProject }
    class property WordsPerPage: Integer read fWordsPerPage write fWordsPerPage;
    class property TimerInterval: Integer read fTimerInterval write fTimerInterval;
  end;

implementation

uses
   Tripous.Broadcaster
  ,o_Consts
  ,o_App
  ,o_Entities

  ;


type

  { TStatsTimer }

  TStatsTimer = class(TTimer)
  private
    procedure Execute(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;



{ TStatsTime }

constructor TStatsTimer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Enabled := False;
  Self.OnTimer := Execute;
end;

procedure TStatsTimer.Execute(Sender: TObject);
begin
  TextMetrics.AccumulateGlobalAll();
end;

{ TTextStats }

procedure TTextStats.Reset();
begin
  WordCount := 0;
  CharCount := 0;
  CharCountNoSpaces := 0;
  LineCount := 0;
  ParagraphCount := 0;
  EstimatedPages := 0;
end;



{ TextMetrics }

class constructor TextMetrics.Create();
begin
  WordsPerPage := 250;
  TimerInterval := 500 * 5;
end;

class destructor TextMetrics.Destroy();
begin
  if Assigned(fTimer) then
    FreeAndNil(fTimer);
end;

class procedure TextMetrics.FinalizeStats(Stats: TTextStats);
begin
  Stats.EstimatedPages := 0;
  if WordsPerPage > 0 then
    Stats.EstimatedPages := Stats.WordCount / WordsPerPage;
end;

class procedure TextMetrics.SetActive(AValue: Boolean);
begin
  if FActive = AValue then
    Exit;

  FActive := AValue;

  if FActive then
  begin
    if not Assigned(fTimer) then
    begin
      fTimer := TStatsTimer.Create(nil);
      fTimer.Enabled := False;
      fTimer.Interval := TimerInterval;
    end;
    FTimer.Enabled := True;

    AccumulateGlobalAll;
  end
  else
  begin
    if Assigned(FTimer) then
      FTimer.Enabled := False;
  end;
end;

class procedure TextMetrics.AccumulateGlobalAll;
begin
  AccumulateGlobal;
  AccumulateGlobalEn;
  Broadcaster.Broadcast(SProjectMetricsChanged, nil);
end;

class procedure TextMetrics.AccumulateStats(Stats: TTextStats; const Text: string);
var
  i: Integer;
  c: Char;
  InWord: Boolean;
  HasNonSpaceInPara: Boolean;
begin
  // Char counts
  Inc(Stats.CharCount, Length(Text));

  // Word/lines/paragraphs - single pass
  InWord := False;
  HasNonSpaceInPara := False;

  for i := 1 to Length(Text) do
  begin
    c := Text[i];

    // Lines: count LF
    if c = #10 then
      Inc(Stats.LineCount);

    // No-spaces count (treat all <= ' ' as whitespace)
    if c > ' ' then
      Inc(Stats.CharCountNoSpaces);

    // Paragraphs: simplistic and stable for markdown writing:
    // count a paragraph when we have seen non-space chars and then hit an empty line boundary.
    // We'll implement as: track HasNonSpaceInPara; when we see LF, lookahead for another LF (empty line),
    // but avoid lookahead complexity: treat consecutive LFs as paragraph boundary.
    if c > ' ' then
      HasNonSpaceInPara := True;

    if c = #10 then
    begin
      // if we encounter an empty line boundary (#10 followed by #10 or end),
      // count paragraph if we had content.
      if (i = Length(Text)) or ((i < Length(Text)) and (Text[i + 1] = #10)) then
      begin
        if HasNonSpaceInPara then
        begin
          Inc(Stats.ParagraphCount);
          HasNonSpaceInPara := False;
        end;
      end;
    end;

    // Words: any run of non-whitespace
    if c > ' ' then
    begin
      if not InWord then
      begin
        InWord := True;
        Inc(Stats.WordCount);
      end;
    end
    else
      InWord := False;
  end;

  // finalize trailing paragraph if text ends with content but no blank line
  if HasNonSpaceInPara then
    Inc(Stats.ParagraphCount);
end;

class procedure TextMetrics.AccumulateGlobal;
var
  Story: TCollectionItem;
  Chapter: TCollectionItem;
  Scene: TCollectionItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  for Story in App.CurrentProject.StoryList do
  begin
    TStory(Story).Stats.Reset();

    for Chapter in TStory(Story).ChapterList do
      for Scene in TChapter(Chapter).SceneList do
        AccumulateStats(TStory(Story).Stats, TScene(Scene).Text);

    FinalizeStats(TStory(Story).Stats);
  end;

end;

class procedure TextMetrics.AccumulateGlobalEn;
var
  Story: TCollectionItem;
  Chapter: TCollectionItem;
  Scene: TCollectionItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  for Story in App.CurrentProject.StoryList do
  begin
    TStory(Story).StatsEn.Reset();

    for Chapter in TStory(Story).ChapterList do
      for Scene in TChapter(Chapter).SceneList do
        AccumulateStats(TStory(Story).StatsEn, TScene(Scene).TextEn);

    FinalizeStats(TStory(Story).StatsEn);
  end;
end;



end.
