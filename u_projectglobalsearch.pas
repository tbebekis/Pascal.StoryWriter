unit u_ProjectGlobalSearch;

{$MODE DELPHI}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Contnrs, LazUTF8, Character,
  o_Entities;

type
  { TProjectGlobalSearch }
  TProjectGlobalSearch = class
  public
    class function Execute(AProject: TProject; const Term: string): TLinkItemList;
  end;

implementation

uses
  o_App
  ;

type
  PInt = ^Integer;

  { TMatchPosList }
  TMatchPosList = class
  private
    FList: TList;
    function GetCount: Integer;
    function GetItem(Index: Integer): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Add(AValue: Integer);
    property Count: Integer read GetCount;
    property Items[Index: Integer]: Integer read GetItem; default;
  end;

  { TLinkHit }
  TLinkHit = class
  public
    BaseItem: TBaseItem;
    Place: TLinkPlace;
    CharPos: Integer;       // 0-based (Unicode chars)
    DisplayTitle: string;   // DisplayTitleInProject
    ItemTypeOrd: Integer;
    IsEnglish: Boolean;
  end;

function IsNullOrWhiteSpace(const S: string): Boolean;
begin
  Result := Trim(S) = '';
end;

function SameTextUtf8(const A, B: string): Boolean;
begin
  Result := UTF8CompareText(A, B) = 0;
end;

function IsWordChar(const C: WideChar): Boolean; inline;
begin
  Result := (C = '_') or TCharacter.IsLetterOrDigit(C);
end;

function FindAllMatchesU(const TextUtf8, TermUtf8: string;
  WholeWord, MatchCase: Boolean): TMatchPosList;
var
  UText, UTerm: UnicodeString;
  USearchText, USearchTerm: UnicodeString;
  i, LText, LTerm: Integer;
  BeforeOk, AfterOk: Boolean;
  CBefore, CAfter: WideChar;
begin
  Result := TMatchPosList.Create;

  if TermUtf8 = '' then
    Exit;

  UText := UTF8Decode(TextUtf8);
  UTerm := UTF8Decode(TermUtf8);

  if MatchCase then
  begin
    USearchText := UText;
    USearchTerm := UTerm;
  end
  else
  begin
    USearchText := UTF8Decode(UTF8LowerCase(TextUtf8));
    USearchTerm := UTF8Decode(UTF8LowerCase(TermUtf8));
  end;

  LText := Length(USearchText);
  LTerm := Length(USearchTerm);
  if (LTerm = 0) or (LTerm > LText) then
    Exit;

  i := 1;
  while True do
  begin
    i := PosEx(USearchTerm, USearchText, i);
    if i = 0 then
      Break;

    if WholeWord then
    begin
      BeforeOk := True;
      AfterOk := True;

      if i > 1 then
      begin
        CBefore := USearchText[i - 1];
        BeforeOk := not IsWordChar(CBefore);
      end;

      if (i + LTerm) <= LText then
      begin
        CAfter := USearchText[i + LTerm];
        AfterOk := not IsWordChar(CAfter);
      end;

      if BeforeOk and AfterOk then
        Result.Add(i - 1); // 0-based
    end
    else
      Result.Add(i - 1);

    Inc(i);
  end;
end;

function CompareHits(A, B: TLinkHit): Integer;
begin
  // ItemType -> DisplayTitle -> Place -> CharPos
  Result := A.ItemTypeOrd - B.ItemTypeOrd;
  if Result <> 0 then Exit;

  Result := UTF8CompareText(A.DisplayTitle, B.DisplayTitle);
  if Result <> 0 then Exit;

  Result := Ord(A.Place) - Ord(B.Place);
  if Result <> 0 then Exit;

  Result := A.CharPos - B.CharPos;
end;

procedure SortHitList(L: TObjectList);

  procedure QuickSort(Lo, Hi: Integer);
  var
    i, j: Integer;
    pivot: TLinkHit;
  begin
    i := Lo;
    j := Hi;
    pivot := TLinkHit(L[(Lo + Hi) div 2]);

    repeat
      while (i <= Hi) and (CompareHits(TLinkHit(L[i]), pivot) < 0) do
        Inc(i);

      while (j >= Lo) and (CompareHits(TLinkHit(L[j]), pivot) > 0) do
        Dec(j);

      if i <= j then
      begin
        L.Exchange(i, j);  // <-- πιο safe από tmp pointer
        Inc(i);
        Dec(j);
      end;
    until i > j;

    if Lo < j then QuickSort(Lo, j);
    if i < Hi then QuickSort(i, Hi);
  end;

begin
  if (L <> nil) and (L.Count > 1) then
    QuickSort(0, L.Count - 1);
end;


{ TMatchPosList }

constructor TMatchPosList.Create;
begin
  inherited Create;
  FList := TList.Create;
end;

destructor TMatchPosList.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TMatchPosList.Clear;
var
  i: Integer;
  p: PInt;
begin
  for i := 0 to FList.Count - 1 do
  begin
    p := PInt(FList[i]);
    Dispose(p);
  end;
  FList.Clear;
end;

procedure TMatchPosList.Add(AValue: Integer);
var
  p: PInt;
begin
  New(p);
  p^ := AValue;
  FList.Add(p);
end;

function TMatchPosList.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TMatchPosList.GetItem(Index: Integer): Integer;
begin
  Result := PInt(FList[Index])^;
end;

{ TProjectGlobalSearch }

class function TProjectGlobalSearch.Execute(AProject: TProject; const Term: string): TLinkItemList;
var
  Hits: TObjectList;       // owns TLinkHit
  PosList: TMatchPosList;
  SearchTerm: string;
  IsWholeWord: Boolean;

  function TrimQuotesWholeWord(const S: string; out WholeWord: Boolean): string;
  begin
    Result := Trim(S);
    WholeWord := (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"');
    if WholeWord then
    begin
      Delete(Result, 1, 1);
      Delete(Result, Length(Result), 1);
      Result := Trim(Result);
    end;
  end;

  procedure AddLinks(BaseItem: TBaseItem; APlace: TLinkPlace; const ADisplayTitle: string);
  var
    k: Integer;
    H: TLinkHit;
  begin
    if (PosList <> nil) and (PosList.Count > 0) then
    begin
      for k := 0 to PosList.Count - 1 do
      begin
        H := TLinkHit.Create;
        H.BaseItem := BaseItem;
        H.Place := APlace;
        H.DisplayTitle := ADisplayTitle;
        H.ItemTypeOrd := Ord(BaseItem.ItemType);
        H.CharPos := PosList[k];
        H.IsEnglish := (APlace = lpTextEn);
        Hits.Add(H);
      end;
    end;
  end;

  procedure AddMatchesForText(BaseItem: TBaseItem; APlace: TLinkPlace; const ATextUtf8, ADisplayTitle: string);
  begin
    FreeAndNil(PosList);
    PosList := FindAllMatchesU(ATextUtf8, SearchTerm, IsWholeWord, {MatchCase=}IsWholeWord);
    AddLinks(BaseItem, APlace, ADisplayTitle);
  end;

  function FindFirstHit: TLinkHit;
  var
    i: Integer;
    H: TLinkHit;
    C: TSWComponent;
  begin
    Result := nil;

    for i := 0 to Hits.Count - 1 do
    begin
      H := TLinkHit(Hits[i]);

      // Title exact match
      if Assigned(H.BaseItem) and SameTextUtf8(H.BaseItem.Title, SearchTerm) then
        Exit(H);

      // Component alias match
      if (H.BaseItem.ItemType = itComponent) and (H.BaseItem is TSWComponent) then
      begin
        C := TSWComponent(H.BaseItem);
        if C.HasAlias(SearchTerm) then
          Exit(H);
      end;
    end;
  end;

  procedure MoveFirstHitToTop(AFirst: TLinkHit);
  begin
    if AFirst = nil then Exit;
    Hits.Extract(AFirst);   // remove without free
    Hits.Insert(0, AFirst);
  end;

  function BuildResultList: TLinkItemList;
  var
    i: Integer;
    H: TLinkHit;
    LI: TLinkItem;
  begin
    Result := TLinkItemList.Create(AProject);

    for i := 0 to Hits.Count - 1 do
    begin
      H := TLinkHit(Hits[i]);
      LI := Result.Add;

      LI.ItemType := H.BaseItem.ItemType;
      LI.Place := H.Place;
      LI.Title := H.DisplayTitle;
      LI.Item := H.BaseItem;
      LI.CharPos := H.CharPos;
      LI.IsEnglish := H.IsEnglish;

      // LI.Id := H.BaseItem.Id; // αν το θες (έχει published Id)
    end;
  end;

var
  iComp, iStory, iChapter, iScene, iNote: Integer;
  Comp: TSWComponent;
  Story: TStory;
  Chapter: TChapter;
  Scene: TScene;
  Note: TNote;
  FirstHit: TLinkHit;
begin
  App.LastGlobalSearchTerm := '';
  App.LastGlobalSearchTermWholeWord := false;

  Result := TLinkItemList.Create(AProject);

  if (AProject = nil) or IsNullOrWhiteSpace(Term) then
    Exit;

  SearchTerm := TrimQuotesWholeWord(Term, IsWholeWord);
  if IsNullOrWhiteSpace(SearchTerm) then
    Exit;

  // αυτά τα κρατάς όπως στο C# (App globals)
  App.LastGlobalSearchTerm := SearchTerm;
  App.LastGlobalSearchTermWholeWord := IsWholeWord;

  Hits := TObjectList.Create(True);
  PosList := nil;
  try
    // ● components
    for iComp := 0 to AProject.ComponentList.Count - 1 do
    begin
      Comp := AProject.ComponentList[iComp];

      AddMatchesForText(Comp, lpTitle, Comp.Title, Comp.DisplayTitleInProject);
      AddMatchesForText(Comp, lpText,  Comp.Text,  Comp.DisplayTitleInProject);

      if not IsNullOrWhiteSpace(Comp.TextEn) then
        AddMatchesForText(Comp, lpTextEn, Comp.TextEn, Comp.DisplayTitleInProject);
    end;

    // ● stories
    for iStory := 0 to AProject.StoryList.Count - 1 do
    begin
      Story := AProject.StoryList[iStory];

      for iChapter := 0 to Story.ChapterList.Count - 1 do
      begin
        Chapter := Story.ChapterList[iChapter];

        for iScene := 0 to Chapter.SceneList.Count - 1 do
        begin
          Scene := Chapter.SceneList[iScene];

          AddMatchesForText(Scene, lpTitle,    Scene.Title,    Scene.DisplayTitleInProject);
          AddMatchesForText(Scene, lpText,     Scene.Text,     Scene.DisplayTitleInProject);

          if not IsNullOrWhiteSpace(Scene.TextEn) then
            AddMatchesForText(Scene, lpTextEn, Scene.TextEn,   Scene.DisplayTitleInProject);

          AddMatchesForText(Scene, lpSynopsis, Scene.Synopsis, Scene.DisplayTitleInProject);
          AddMatchesForText(Scene, lpTimeline, Scene.Timeline, Scene.DisplayTitleInProject);
        end;

        AddMatchesForText(Chapter, lpTitle,    Chapter.Title,    Chapter.DisplayTitleInProject);
        AddMatchesForText(Chapter, lpSynopsis, Chapter.Synopsis, Chapter.DisplayTitleInProject);
      end;

      AddMatchesForText(Story, lpTitle,    Story.Title,    Story.DisplayTitleInProject);
      AddMatchesForText(Story, lpSynopsis, Story.Synopsis, Story.DisplayTitleInProject);
    end;

    // ● notes
    for iNote := 0 to AProject.NoteList.Count - 1 do
    begin
      Note := AProject.NoteList[iNote];

      AddMatchesForText(Note, lpTitle, Note.Title, Note.DisplayTitleInProject);
      AddMatchesForText(Note, lpText,  Note.Text,  Note.DisplayTitleInProject);
    end;

    if Hits.Count = 0 then
      Exit;

    // capture best match BEFORE sort (as object reference)
    FirstHit := FindFirstHit;

    // sort
    SortHitList(Hits);

    // move FirstHit to top AFTER sort
    MoveFirstHitToTop(FirstHit);

    // replace empty result with real result
    FreeAndNil(Result);
    Result := BuildResultList;

  finally
    FreeAndNil(PosList);
    Hits.Free;
  end;
end;

end.

