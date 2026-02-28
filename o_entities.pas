unit o_Entities;

{$MODE DELPHI}{$H+}
{$modeswitch nestedprocvars}
{$WARN 5024 off : Parameter "$1" not used}

interface

uses
   Classes
  ,SysUtils
  ,Types
  ,Contnrs
  ,Tripous
  ,o_TextStats
  ;

type
  { Forward declarations }
  TProject = class;
  TStory = class;
  TChapter = class;
  TScene = class;
  TSWComponent = class;
  TNote = class;
  TLinkItem = class;
  TLinkItemList = class;
  TQuickView = class;

  { ItemType }
  TItemType = (
    itNone      = 0,
    itCategory  = 1,
    itTag       = 2,
    itComponent = 3,
    itStory     = 4,
    itChapter   = 5,
    itScene     = 6,
    itNote      = 7
  );

  { Base item for collection-based entities }

  { TBaseItem }

  TBaseItem = class(TCollectionItem)
  private
    fId: string;
    function GetIsFirst: Boolean;
    function GetIsLast: Boolean;
  protected
    function GetItemType: TItemType; virtual;
    function GetId: string; virtual;

    function GetTitle: string; virtual; abstract;
    procedure SetTitle(const Value: string); virtual; abstract;

    function GetDisplayTitle: string; virtual; abstract;
    function GetDisplayTitleInStory: string; virtual; abstract;
    function GetDisplayTitleInProject: string; virtual; abstract;

    class function CanMoveInCollection(Item: TCollectionItem; Up: Boolean): Boolean; static;
    class function MoveInCollection(Item: TCollectionItem; Up: Boolean): Boolean; static;
  public
    function ToString: string; override;

    function TitleContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean; virtual;
    function TextContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean; virtual;
    function SynopsisContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean; virtual;
    function TimelineContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean; virtual;

    function TitleToFileName(const ATitle: string; RemoveSpaces: Boolean = False): string; virtual;

    property ItemType: TItemType read GetItemType;

    property IsFirst: Boolean read GetIsFirst;
    property IsLast: Boolean read GetIsLast;
  published
    property Id: string read GetId write fId;
    property Title: string read GetTitle write SetTitle;
  public
    property DisplayTitle: string read GetDisplayTitle;
    property DisplayTitleInStory: string read GetDisplayTitleInStory;
    property DisplayTitleInProject: string read GetDisplayTitleInProject;
  end;

  { --- Typed Collections ---------------------------------------------------- }

  TSWComponentCollection = class;
  TStoryCollection = class;
  TChapterCollection = class;
  TSceneCollection = class;
  TNoteCollection = class;

  { TSWComponent }
  TSWComponent = class(TBaseItem)
  private
    fTitle: string;
    fCategory: string;
    fProject: TProject;

    fText: string;
    fTextEn: string;

    fTagList: TStrings;
    fAliasList: TStrings;

    function GetFolderPath: string;
    function GetFolderPathEn: string;
    function GetTextFilePath: string;
    function GetTextFilePathEn: string;

    function GetAliases: string;
    procedure SetAliases(const Value: string);
    function GetTags: string;
    procedure SetTags(const Value: string);
  protected
    function GetItemType: TItemType; override;

    function GetTitle: string; override;
    procedure SetTitle(const Value: string); override;

    function GetDisplayTitle: string; override;
    function GetDisplayTitleInStory: string; override;
    function GetDisplayTitleInProject: string; override;
  public
    constructor Create(ACollection: TCollection = nil); override;
    destructor Destroy; override;

    procedure Load;
    procedure Save;
    procedure Delete;

    function ContainsTag(const Tag: string): Boolean;
    function HasAlias(const Alias: string): Boolean;

    procedure AddTag(const Tag: string);
    procedure RemoveTag(const Tag: string);

    function GetTagsAsLine: string;
    procedure SetTagsFrom(SourceList: TStrings);

    function TextContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean; override;

    property Project: TProject read fProject write fProject;
    property Text: string read fText write fText;
    property TextEn: string read fTextEn write fTextEn;

    property FolderPath: string read GetFolderPath;
    property FolderPathEn: string read GetFolderPathEn;
    property TextFilePath: string read GetTextFilePath;
    property TextFilePathEn: string read GetTextFilePathEn;

    property Aliases: string read GetAliases write SetAliases;
    property Tags: string read GetTags write SetTags;
  published
    property Category: string read fCategory write fCategory;
    property TagList: TStrings read fTagList write fTagList;
    property AliasList: TStrings read fAliasList write fAliasList;
  end;



  { TStory }
  TStory = class(TBaseItem)
  private
    fStats: TTextStats;
    fStatsEn: TTextStats;

    fTitle: string;
    fLastFolderPath: string;

    fProject: TProject;
    fSynopsis: string;

    fChapterList: TChapterCollection;

    function GetOrderIndex: Integer;
    function GetFolderPath: string;
    function GetSynopsisFilePath: string;
  protected
    function GetItemType: TItemType; override;

    function GetTitle: string; override;
    procedure SetTitle(const Value: string); override;

    function GetDisplayTitle: string; override;
    function GetDisplayTitleInStory: string; override;
    function GetDisplayTitleInProject: string; override;
  public
    constructor Create(ACollection: TCollection = nil); override;
    destructor Destroy; override;

    procedure Load;
    procedure Save;
    procedure SaveSynopsis;
    procedure Delete;

    function CanMove(Up: Boolean): Boolean;
    function Move(Up: Boolean): Boolean;
    procedure FolderPathChanging;
    procedure FolderPathChanged;

    function CountChapterTitle(const ChapterTitle: string): Integer;
    function AddChapter(const Title: string): TChapter;

    function SynopsisContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean; override;

    property Project: TProject read fProject write fProject;
    property Synopsis: string read fSynopsis write fSynopsis;

    property OrderIndex: Integer read GetOrderIndex;
    property FolderPath: string read GetFolderPath;
    property SynopsisFilePath: string read GetSynopsisFilePath;

    function ChapterCount: Integer;
    function ChapterAt(Index: Integer): TChapter;

    property Stats: TTextStats read fStats;
    property StatsEn: TTextStats read fStatsEn;
  published
    property ChapterList: TChapterCollection read fChapterList;
  end;

  { TChapter }
  TChapter = class(TBaseItem)
  private
    fTitle: string;
    fLastFolderPath: string;

    fStory: TStory;
    fSynopsis: string;

    fSceneList: TSceneCollection;

    function GetOrderIndex: Integer;
    function GetFolderPath: string;
    function GetSynopsisFilePath: string;
  protected
    function GetItemType: TItemType; override;

    function GetTitle: string; override;
    procedure SetTitle(const Value: string); override;

    function GetDisplayTitle: string; override;
    function GetDisplayTitleInStory: string; override;
    function GetDisplayTitleInProject: string; override;
  public
    constructor Create(ACollection: TCollection = nil); override;
    destructor Destroy; override;

    procedure Load;
    procedure Save;
    procedure SaveSynopsis;
    procedure Delete;

    function CanMove(Up: Boolean): Boolean;
    function Move(Up: Boolean): Boolean;

    procedure ChangeParent(NewStory: TStory);

    procedure FolderPathChanging;
    procedure FolderPathChanged;

    function CountSceneTitle(const SceneTitle: string): Integer;
    function AddScene(const Title: string): TScene;

    function SynopsisContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean; override;

    property Story: TStory read fStory write fStory;
    property Synopsis: string read fSynopsis write fSynopsis;

    property OrderIndex: Integer read GetOrderIndex;
    property FolderPath: string read GetFolderPath;
    property SynopsisFilePath: string read GetSynopsisFilePath;

    function SceneCount: Integer;
    function SceneAt(Index: Integer): TScene;
  published
    property SceneList: TSceneCollection read fSceneList;
  end;

  { TScene }
  TScene = class(TBaseItem)
  private
    fTitle: string;
    fLastFolderPath: string;

    fChapter: TChapter;

    fSynopsis: string;
    fText: string;
    fTextEn: string;
    fTimeline: string;

    function GetOrderIndex: Integer;

    function GetFolderPath: string;
    function GetSynopsisFilePath: string;
    function GetTextFilePath: string;
    function GetTextEnFilePath: string;
    function GetTimelineFilePath: string;
  protected
    function GetItemType: TItemType; override;

    function GetTitle: string; override;
    procedure SetTitle(const Value: string); override;

    function GetDisplayTitle: string; override;
    function GetDisplayTitleInStory: string; override;
    function GetDisplayTitleInProject: string; override;
  public
    constructor Create(ACollection: TCollection = nil); override;

    procedure Load;
    procedure Save;
    procedure Delete;

    procedure SaveSynopsis;
    procedure SaveText;
    procedure SaveTextEn;
    procedure SaveTimeline;

    function CanMove(Up: Boolean): Boolean;
    function Move(Up: Boolean): Boolean;

    procedure ChangeParent(NewChapter: TChapter);

    procedure FolderPathChanging;
    procedure FolderPathChanged;

    function TextContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean; override;
    function SynopsisContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean; override;
    function TimelineContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean; override;

    property Chapter: TChapter read fChapter write fChapter;

    property Synopsis: string read fSynopsis write fSynopsis;
    property Text: string read fText write fText;
    property TextEn: string read fTextEn write fTextEn;
    property Timeline: string read fTimeline write fTimeline;

    property OrderIndex: Integer read GetOrderIndex;

    property FolderPath: string read GetFolderPath;
    property SynopsisFilePath: string read GetSynopsisFilePath;
    property TextFilePath: string read GetTextFilePath;
    property TextEnFilePath: string read GetTextEnFilePath;
    property TimelineFilePath: string read GetTimelineFilePath;
  end;

  { TNote }
  TNote = class(TBaseItem)
  private
    fTitle: string;
    fLastTextFilePath: string;

    fProject: TProject;
    fText: string;

    function GetOrderIndex: Integer;
    function GetFolderPath: string;
    function GetTextFilePath: string;
  protected
    function GetItemType: TItemType; override;

    function GetTitle: string; override;
    procedure SetTitle(const Value: string); override;

    function GetDisplayTitle: string; override;
    function GetDisplayTitleInStory: string; override;
    function GetDisplayTitleInProject: string; override;
  public
    constructor Create(ACollection: TCollection = nil); override;

    procedure Load;
    procedure Save;
    procedure Delete;

    function CanMove(Up: Boolean): Boolean;
    function Move(Up: Boolean): Boolean;

    procedure FilePathChanging;
    procedure FilePathChanged;

    function TextContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean; override;

    property Project: TProject read fProject write fProject;
    property Text: string read fText write fText;

    property OrderIndex: Integer read GetOrderIndex;
    property FolderPath: string read GetFolderPath;
    property TextFilePath: string read GetTextFilePath;
  end;

  { --- Collection classes (typed) ------------------------------------------ }

  TCollectionFindMethod = function(Item: TCollectionItem): Boolean of object;
  TCollectionFindFunc = function(Item: TCollectionItem): Boolean;

  { TCollectionBase }

  TCollectionBase = class(TCollection)
  private
    function GetFirst: TCollectionItem;
    function GetLast: TCollectionItem;
  public
    function IndexOf(Item: TCollectionItem): Integer;
    function Remove(Item: TCollectionItem): Boolean;
    function FindItem(Func: TCollectionFindMethod): TCollectionItem; overload;
    function FindItem(Func: TCollectionFindFunc): TCollectionItem; overload;

    property First: TCollectionItem read GetFirst;
    property Last: TCollectionItem read GetLast;
  end;

  TSWComponentCollection = class(TCollection)
  private
    function GetItem(Index: Integer): TSWComponent;
  public
    constructor Create;
    function Add: TSWComponent;
    property Items[Index: Integer]: TSWComponent read GetItem; default;
  end;

  TSceneCollection = class(TCollection)
  private
    function GetItem(Index: Integer): TScene;
  public
    constructor Create;
    function Add: TScene;
    property Items[Index: Integer]: TScene read GetItem; default;
  end;

  TChapterCollection = class(TCollection)
  private
    function GetItem(Index: Integer): TChapter;
  public
    constructor Create;
    function Add: TChapter;
    property Items[Index: Integer]: TChapter read GetItem; default;
  end;

  TStoryCollection = class(TCollection)
  private
    function GetItem(Index: Integer): TStory;
  public
    constructor Create;
    function Add: TStory;
    property Items[Index: Integer]: TStory read GetItem; default;
  end;

  TNoteCollection = class(TCollection)
  private
    function GetItem(Index: Integer): TNote;
  public
    constructor Create;
    function Add: TNote;
    property Items[Index: Integer]: TNote read GetItem; default;
  end;

  { TProject }
  TProject = class(TPersistent)
  public const
    ComponentsFolderName   = 'Components';
    ComponentsFolderNameEn = 'ComponentsEn';
    ImagesFolderName       = 'Images';
    WikiFolderName         = 'Wiki';
    WikiFolderNameEn       = 'WikiEn';
  private
    fLoading: Boolean;
    fFolderPath: string;
    fQuickView: TQuickView;

    fTempText: string;
    fMarkdownTempText: string;

    fId: string;
    fTitle: string;

    fStoryList: TStoryCollection;
    fComponentList: TSWComponentCollection;
    fNoteList: TNoteCollection;

    function GetId: string;

    function GetImagesFolderPath: string;
    function GetComponentsFolderPath: string;
    function GetComponentsFolderPathEn: string;
    function GetWikiFolderPath: string;
    function GetWikiFolderPathEn: string;

    function GetProjectFilePath: string;
    function GetTempFilePath: string;
    function GetMarkdownTempFilePath: string;
    function GetQuickViewListFilePath: string;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    function GetAllChapters: TList;
    function GetAllScenes: TList;

    function FindComponentById(const Id: string): TSWComponent;
    function FindNoteById(const Id: string): TNote;
    function FindChapterById(const Id: string): TChapter;
    function FindSceneById(const Id: string): TScene;

    procedure Load;
    procedure Save;
    procedure SaveJson;

    procedure SaveTempText;
    procedure SaveMarkdownTempText;

    function CountStoryTitle(const StoryTitle: string): Integer;
    function CountNoteTitle(const NoteTitle: string): Integer;
    function CountComponentTitle(const ComponentTitle: string): Integer;

    function AddStory(const Title: string): TStory;
    function AddNote(const Title: string; const NoteText: string = ''): TNote;
    function AddComponent(const Title: string): TSWComponent; overload;
    function AddComponent(AComponent: TSWComponent): TSWComponent; overload;

    function GetCategoryList(SourceList: TSWComponentCollection = nil): TStrings;            // sorted
    function GetTagList(SourceList: TSWComponentCollection = nil): TStrings;                 // sorted
    function GetComponentList(): TObjectList;                                                // sorted by Title

    function CategoryExists(const Category: string): Boolean;
    function TagExists(const Tag: string): Boolean;

    function StoryCount: Integer;
    function StoryAt(Index: Integer): TStory;

    function ComponentCount: Integer;
    function ComponentAt(Index: Integer): TSWComponent;

    function NoteCount: Integer;
    function NoteAt(Index: Integer): TNote;

    function GetComponentListText(): string;

    // ● global search
    function  GlobalSearch(const Term: string): TLinkItemList;

    property Loading: Boolean read fLoading;
    property FolderPath: string read fFolderPath write fFolderPath;

    property ImagesFolderPath: string read GetImagesFolderPath;
    property ComponentsFolderPath: string read GetComponentsFolderPath;
    property ComponentsFolderPathEn: string read GetComponentsFolderPathEn;
    property WikiFolderPath: string read GetWikiFolderPath;
    property WikiFolderPathEn: string read GetWikiFolderPathEn;

    property ProjectFilePath: string read GetProjectFilePath;
    property TempFilePath: string read GetTempFilePath;
    property MarkdownTempFilePath: string read GetMarkdownTempFilePath;
    property QuickViewListFilePath: string read GetQuickViewListFilePath;

    property TempText: string read fTempText write fTempText;
    property MarkdownTempText: string read fMarkdownTempText write fMarkdownTempText;

    property QuickView: TQuickView read fQuickView;
  published
    property Id: string read GetId write fId;
    property Title: string read fTitle write fTitle;

    property StoryList: TStoryCollection read fStoryList;
    property ComponentList: TSWComponentCollection read fComponentList;
    property NoteList: TNoteCollection read fNoteList;
  end;

  TLinkPlace = (
     lpTitle    = 0,
     lpText     = 1,
     lpTextEn   = 2,
     lpSynopsis = 3,
     lpTimeline = 4
  );

{ TLinkItem }
  TLinkItem = class(TCollectionItem)
  private
    fColumn: Integer;
    fId: string;
    fLine: Integer;
    fLineText: string;
    fTitle: string;
    fItemType: TItemType;
    fPlace: TLinkPlace;
    //fCharPos: Integer;
    fIsEnglish: Boolean;
    fItem: TBaseItem;

    function GetId: string;
    procedure SetId(const AValue: string);

    function GetTitle: string;
    procedure SetTitle(const AValue: string);
  public
    constructor Create(ACollection: TCollection); override; overload;
    constructor Create(ACollection: TCollection; AType: TItemType; APlace: TLinkPlace; const ATitle: string; AItem: TBaseItem); overload;

    function ToString: string; override;
    procedure LoadItem();

    function CanMove(Up: Boolean): Boolean;
    function Move(Up: Boolean): Boolean;

    property Item: TBaseItem read fItem write fItem;
    property LineText: string read fLineText write fLineText;
    property Line: Integer read fLine write fLine;
    property Column: Integer read fColumn write fColumn;
  published
    property Id: string read GetId write SetId;
    property Title: string read GetTitle write SetTitle;
    property ItemType: TItemType read fItemType write fItemType;
    property Place: TLinkPlace read fPlace write fPlace;
    //property CharPos: Integer read fCharPos write fCharPos;
    property IsEnglish: Boolean read fIsEnglish write fIsEnglish;
  end;

  { TLinkItemList }
  TLinkItemList = class(TCollection)
  private
    fOwner: TPersistent;
    function GetItem(Index: Integer): TLinkItem;
    procedure SetItem(Index: Integer; const Value: TLinkItem);
  protected
    function GetOwner: TPersistent; override;
  public
    constructor Create(AOwner: TPersistent);

    function FindById(const Id: string): TLinkItem;

    function Add: TLinkItem;
    property Items[Index: Integer]: TLinkItem read GetItem write SetItem; default;
  end;

  { TQuickView }

  TQuickView = class(TPersistent)
  private
    FList: TLinkItemList;
  public
    constructor Create();
    destructor Destroy(); override;

    function FindById(const Id: string): TLinkItem;
    procedure Clear();

    procedure ClearAndSave();

    procedure Save();
    procedure Load();
  published
    property List: TLinkItemList read FList write FList;
  end;

  function ItemTypeToString(Value: TItemType): string;
  function LinkPlaceToString(Value: TLinkPlace): string;
  function StringToLinkPlace(const S: string): TLinkPlace;

implementation

uses
   o_ProjectGlobalSearch
  ,o_App
  ;

function ItemTypeToString(Value: TItemType): string;
begin
  case Value of
    itNone      : Result := 'None';
    itCategory  : Result := 'Category';
    itTag       : Result := 'Tag';
    itComponent : Result := 'Component';
    itStory     : Result := 'Story';
    itChapter   : Result := 'Chapter';
    itScene     : Result := 'Scene';
    itNote      : Result := 'Note';
  else
    Result := 'None';
  end;
end;

function LinkPlaceToString(Value: TLinkPlace): string;
begin
  case Value of
    lpTitle    : Result := 'Title';
    lpText     : Result := 'Text';
    lpTextEn   : Result := 'TextEn';
    lpSynopsis : Result := 'Synopsis';
    lpTimeline : Result := 'Timeline';
  else
    Result := 'Title';
  end;
end;

function StringToLinkPlace(const S: string): TLinkPlace;
begin
  if SameText(S, 'Title') then Exit(lpTitle);
  if SameText(S, 'Text') then Exit(lpText);
  if SameText(S, 'TextEn') then Exit(lpTextEn);
  if SameText(S, 'Synopsis') then Exit(lpSynopsis);
  if SameText(S, 'Timeline') then Exit(lpTimeline);
  Result := lpTitle;
end;

{ TBaseItem }

class function TBaseItem.CanMoveInCollection(Item: TCollectionItem; Up: Boolean): Boolean;
begin
  Result := False;
  if (Item = nil) or (Item.Collection = nil) then Exit;
  if Up then
    Result := Item.Index > 0
  else
    Result := Item.Index < Item.Collection.Count - 1;
end;

class function TBaseItem.MoveInCollection(Item: TCollectionItem; Up: Boolean): Boolean;
begin
  Result := False;
  if not CanMoveInCollection(Item, Up) then Exit;

  if Up then
    Item.Index := Item.Index - 1
  else
    Item.Index := Item.Index + 1;

  Result := True;
end;

function TBaseItem.GetId: string;
begin
  if Sys.IsEmpty(fId) then
    fId := Sys.GenId(False);
  Result := fId;
end;

function TBaseItem.GetIsFirst: Boolean;
begin
  Result := False;
  if Assigned(Collection) then
    Result := TCollectionBase(Collection).First = Self;
end;

function TBaseItem.GetIsLast: Boolean;
begin
  Result := False;
  if Assigned(Collection) then
    Result := TCollectionBase(Collection).Last = Self;
end;

function TBaseItem.GetItemType: TItemType;
begin
  if Self is TSWComponent then Exit(itComponent);
  if Self is TScene then Exit(itScene);
  if Self is TChapter then Exit(itChapter);
  if Self is TStory then Exit(itStory);
  if Self is TNote then Exit(itNote);
  Result := itNone;
end;

function TBaseItem.ToString: string;
begin
  Result := DisplayTitle;
end;

function TBaseItem.TitleContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean;
begin
  if WholeWordOnly then
    Result := App.ContainsWord(Title, Term)
  else
    Result := App.ContainsText(Title, Term);
end;

function TBaseItem.TextContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean;
begin
  Result := False;
end;

function TBaseItem.SynopsisContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean;
begin
  Result := False;
end;

function TBaseItem.TimelineContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean;
begin
  Result := False;
end;

function TBaseItem.TitleToFileName(const ATitle: string; RemoveSpaces: Boolean): string;
var
  S: string;
begin
  S := ATitle;
  if RemoveSpaces and (not Sys.IsEmpty(S)) then
    S := StringReplace(S, ' ', '', [rfReplaceAll]);

  S := Sys.StrToValidFileName(S);
  Result := S;
end;



{ --- Typed Collections ------------------------------------------------------ }

constructor TSWComponentCollection.Create;
begin
  inherited Create(TSWComponent);
end;

function TSWComponentCollection.Add: TSWComponent;
begin
  Result := TSWComponent(inherited Add);
end;

function TSWComponentCollection.GetItem(Index: Integer): TSWComponent;
begin
  Result := TSWComponent(inherited Items[Index]);
end;

constructor TSceneCollection.Create;
begin
  inherited Create(TScene);
end;

function TSceneCollection.Add: TScene;
begin
  Result := TScene(inherited Add);
end;

function TSceneCollection.GetItem(Index: Integer): TScene;
begin
  Result := TScene(inherited Items[Index]);
end;

constructor TChapterCollection.Create;
begin
  inherited Create(TChapter);
end;

function TChapterCollection.Add: TChapter;
begin
  Result := TChapter(inherited Add);
end;

function TChapterCollection.GetItem(Index: Integer): TChapter;
begin
  Result := TChapter(inherited Items[Index]);
end;

constructor TStoryCollection.Create;
begin
  inherited Create(TStory);
end;

function TStoryCollection.Add: TStory;
begin
  Result := TStory(inherited Add);
end;

function TStoryCollection.GetItem(Index: Integer): TStory;
begin
  Result := TStory(inherited Items[Index]);
end;

constructor TNoteCollection.Create;
begin
  inherited Create(TNote);
end;

function TNoteCollection.Add: TNote;
begin
  Result := TNote(inherited Add);
end;

function TNoteCollection.GetItem(Index: Integer): TNote;
begin
  Result := TNote(inherited Items[Index]);
end;

{ TSWComponent }

constructor TSWComponent.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  fText := '';
  fTextEn := '';
  fTagList := TStringList.Create;
  fAliasList := TStringList.Create;
end;

destructor TSWComponent.Destroy;
begin
  fAliasList.Free;
  fTagList.Free;
  inherited Destroy;
end;

function TSWComponent.GetItemType: TItemType;
begin
  Result := itComponent;
end;

function TSWComponent.GetTitle: string;
begin
  Result := fTitle;
end;

procedure TSWComponent.SetTitle(const Value: string);
var
  NewTextFilePath: string;
begin
  App.CheckValidFileName(Value);

  if (Project = nil) or Project.Loading then
  begin
    fTitle := Value;
    Exit;
  end;

  if not Sys.IsSameText(fTitle, Value) then
  begin
    if FileExists(TextFilePath) then
    begin
      NewTextFilePath := Sys.CombinePaths([FolderPath, TitleToFileName(Value, True) + '.md']);
      RenameFile(TextFilePath, NewTextFilePath);
    end;

    if FileExists(TextFilePathEn) then
    begin
      NewTextFilePath := Sys.CombinePaths([FolderPathEn, TitleToFileName(Value, True) + '.md']);
      RenameFile(TextFilePathEn, NewTextFilePath);
    end;

    fTitle := Value;
    Project.SaveJson;
  end;
end;

function TSWComponent.GetDisplayTitle: string;
begin
  Result := Title;
end;

function TSWComponent.GetDisplayTitleInStory: string;
begin
  Result := Title;
end;

function TSWComponent.GetDisplayTitleInProject: string;
begin
  Result := Title;
end;

function TSWComponent.GetFolderPath: string;
begin
  if Project <> nil then
    Result := Project.ComponentsFolderPath
  else
    Result := '';
end;

function TSWComponent.GetFolderPathEn: string;
begin
  if Project <> nil then
    Result := Project.ComponentsFolderPathEn
  else
    Result := '';
end;

function TSWComponent.GetTextFilePath: string;
begin
  Result := Sys.CombinePaths([FolderPath, TitleToFileName(Title, True) + '.md']);
end;

function TSWComponent.GetTextFilePathEn: string;
begin
  Result := Sys.CombinePaths([FolderPathEn, TitleToFileName(Title, True) + '.md']);
end;

procedure TSWComponent.Load;
begin
  if FileExists(TextFilePath) then
    fText := Sys.LoadFromFile(TextFilePath);

  if FileExists(TextFilePathEn) then
    fTextEn := Sys.LoadFromFile(TextFilePathEn);
end;

procedure TSWComponent.Save;
begin
  Sys.CreateFolders(FolderPath);
  Sys.SaveToFile(TextFilePath, Text);

  Sys.CreateFolders(FolderPathEn);
  Sys.SaveToFile(TextFilePathEn, TextEn);
end;

procedure TSWComponent.Delete;
begin
  if FileExists(TextFilePath) then
    SysUtils.DeleteFile(TextFilePath);

  if FileExists(TextFilePathEn) then
    SysUtils.DeleteFile(TextFilePathEn);

  if Project <> nil then
  begin
    if Assigned(Project.ComponentList) then
      Project.ComponentList.Delete(Index);
    Project.SaveJson;
  end;
end;

function TSWComponent.ContainsTag(const Tag: string): Boolean;
begin
  Result := fTagList.IndexOf(Tag) >= 0;
end;

function TSWComponent.HasAlias(const Alias: string): Boolean;
begin
  Result := fAliasList.IndexOf(Alias) >= 0;
end;

procedure TSWComponent.AddTag(const Tag: string);
begin
  App.CheckValidFileName(Tag);

  if fTagList.IndexOf(Tag) < 0 then
  begin
    fTagList.Add(Tag);
    if Project <> nil then
      Project.SaveJson;
  end;
end;

procedure TSWComponent.RemoveTag(const Tag: string);
var
  I: Integer;
begin
  I := fTagList.IndexOf(Tag);
  if I >= 0 then
  begin
    fTagList.Delete(I);
    if Project <> nil then
      Project.SaveJson;
  end;
end;

function TSWComponent.GetTagsAsLine: string;
begin
  if fTagList.Count = 0 then
    Exit('');
  Result := StringReplace(fTagList.CommaText, ',', ', ', [rfReplaceAll]);
end;

procedure TSWComponent.SetTagsFrom(SourceList: TStrings);
begin
  fTagList.Clear;
  fTagList.AddStrings(SourceList);


  if Project <> nil then
    Project.SaveJson;
end;

function TSWComponent.TextContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean;
begin
  if WholeWordOnly then
    Result := App.ContainsWord(Text, Term)
  else
    Result := App.ContainsText(Text, Term);
end;

function TSWComponent.GetAliases: string;
begin
  Result := StringReplace(fAliasList.CommaText, ',', ', ', [rfReplaceAll]);
end;

procedure TSWComponent.SetAliases(const Value: string);
begin
  fAliasList.CommaText := Value;
end;

function TSWComponent.GetTags: string;
begin
  Result := StringReplace(fTagList.CommaText, ',', ', ', [rfReplaceAll]);
end;

procedure TSWComponent.SetTags(const Value: string);
begin
  fTagList.CommaText := Value;
end;

{ TStory }

constructor TStory.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  fSynopsis := '';
  fChapterList := TChapterCollection.Create;
  fStats := TTextStats.Create;
  fStatsEn := TTextStats.Create;
end;

destructor TStory.Destroy;
begin
  fStats.Free();
  fStatsEn.Free();
  fChapterList.Free;
  inherited Destroy;
end;

function TStory.GetItemType: TItemType;
begin
  Result := itStory;
end;

function TStory.GetTitle: string;
begin
  Result := fTitle;
end;

procedure TStory.SetTitle(const Value: string);
var
  NewFolder: string;
begin
  App.CheckValidFileName(Value);

  if (Project = nil) or Project.Loading then
  begin
    fTitle := Value;
    Exit;
  end;

  if not Sys.IsSameText(fTitle, Value) then
  begin
    if DirectoryExists(FolderPath) then
    begin
      NewFolder := Sys.CombinePaths([Project.FolderPath, IntToStr(OrderIndex + 1) + '. ' + TitleToFileName(Value, False)]);
      RenameFile(FolderPath, NewFolder);
    end;

    fTitle := Value;
    Project.SaveJson;
  end;
end;

function TStory.GetOrderIndex: Integer;
begin
  Result := Index;
end;

function TStory.GetFolderPath: string;
begin
  if Project = nil then Exit('');
  Result := Sys.CombinePaths([Project.FolderPath, IntToStr(OrderIndex + 1) + '. ' + TitleToFileName(Title, False)]);
end;

function TStory.GetSynopsisFilePath: string;
begin
  Result := Sys.CombinePaths([FolderPath, 'Synopsis.txt']);
end;

function TStory.GetDisplayTitle: string;
begin
  Result := IntToStr(OrderIndex + 1) + '. ' + Title;
end;

function TStory.GetDisplayTitleInStory: string;
begin
  Result := DisplayTitle;
end;

function TStory.GetDisplayTitleInProject: string;
begin
  Result := DisplayTitle;
end;

procedure TStory.Load;
var
  I: Integer;
  C: TChapter;
begin
  if FileExists(SynopsisFilePath) then
    fSynopsis := Sys.LoadFromFile(SynopsisFilePath);

  for I := 0 to fChapterList.Count - 1 do
  begin
    C := fChapterList[I];
    C.Story := Self;
    C.Load;
  end;
end;

procedure TStory.Save;
var
  I: Integer;
begin
  Sys.CreateFolders(FolderPath);
  Sys.SaveToFile(SynopsisFilePath, Synopsis);

  for I := 0 to fChapterList.Count - 1 do
    fChapterList[I].Save;
end;

procedure TStory.SaveSynopsis;
begin
  Sys.CreateFolders(FolderPath);
  Sys.SaveToFile(SynopsisFilePath, Synopsis);
end;

procedure TStory.Delete;
var
  I: Integer;
  S: TStory;
begin
  if DirectoryExists(FolderPath) then
    Sys.FolderDelete(FolderPath);

  if (Project <> nil) and Assigned(Project.StoryList) then
  begin
    for I := 0 to Project.StoryList.Count - 1 do
    begin
      S := Project.StoryList[I];
      S.FolderPathChanging;
    end;

    Project.StoryList.Delete(Index);

    for I := 0 to Project.StoryList.Count - 1 do
    begin
      S := Project.StoryList[I];
      S.FolderPathChanged;
    end;

    Project.SaveJson;
  end;
end;

function TStory.CanMove(Up: Boolean): Boolean;
begin
  Result := CanMoveInCollection(Self, Up);
end;

function TStory.Move(Up: Boolean): Boolean;
var
  I: Integer;
  S: TStory;
begin
  Result := False;
  if (Project = nil) or (not CanMove(Up)) then Exit;

  for I := 0 to Project.StoryList.Count - 1 do
    Project.StoryList[I].FolderPathChanging;

  Result := MoveInCollection(Self, Up);

  for I := 0 to Project.StoryList.Count - 1 do
  begin
    S := Project.StoryList[I];
    S.FolderPathChanged;
  end;

  Project.SaveJson;
end;

procedure TStory.FolderPathChanging;
begin
  fLastFolderPath := FolderPath;
end;

procedure TStory.FolderPathChanged;
begin
  if (fLastFolderPath <> FolderPath) and DirectoryExists(fLastFolderPath) then
    RenameFile(fLastFolderPath, FolderPath);
end;

function TStory.CountChapterTitle(const ChapterTitle: string): Integer;
var
  I: Integer;
  C: TChapter;
begin
  Result := 0;
  for I := 0 to fChapterList.Count - 1 do
  begin
    C := fChapterList[I];
    if Sys.IsSameText(C.Title, ChapterTitle) then
      Inc(Result);
  end;
end;

function TStory.AddChapter(const Title: string): TChapter;
begin
  Result := fChapterList.Add;
  Result.Story := Self;
  Result.Title := Title;
  if Project <> nil then
    Project.SaveJson;
end;

function TStory.SynopsisContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean;
begin
  if WholeWordOnly then
    Result := App.ContainsWord(Synopsis, Term)
  else
    Result := App.ContainsText(Synopsis, Term);
end;

function TStory.ChapterCount: Integer;
begin
  Result := fChapterList.Count;
end;

function TStory.ChapterAt(Index: Integer): TChapter;
begin
  Result := fChapterList[Index];
end;

{ TChapter }

constructor TChapter.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  fSynopsis := '';
  fSceneList := TSceneCollection.Create;
end;

destructor TChapter.Destroy;
begin
  fSceneList.Free;
  inherited Destroy;
end;

function TChapter.GetItemType: TItemType;
begin
  Result := itChapter;
end;

function TChapter.GetTitle: string;
begin
  Result := fTitle;
end;

procedure TChapter.SetTitle(const Value: string);
var
  NewFolder: string;
begin
  App.CheckValidFileName(Value);

  if (Story = nil) or (Story.Project = nil) or Story.Project.Loading then
  begin
    fTitle := Value;
    Exit;
  end;

  if not Sys.IsSameText(fTitle, Value) then
  begin
    if DirectoryExists(FolderPath) then
    begin
      NewFolder := Sys.CombinePaths([Story.FolderPath, IntToStr(OrderIndex + 1) + '. ' + TitleToFileName(Value, False)]);
      RenameFile(FolderPath, NewFolder);
    end;

    fTitle := Value;
    Story.Project.SaveJson;
  end;
end;

function TChapter.GetOrderIndex: Integer;
begin
  Result := Index;
end;

function TChapter.GetFolderPath: string;
begin
  if Story = nil then Exit('');
  Result := Sys.CombinePaths([Story.FolderPath, IntToStr(OrderIndex + 1) + '. ' + TitleToFileName(Title, False)]);
end;

function TChapter.GetSynopsisFilePath: string;
begin
  Result := Sys.CombinePaths([FolderPath, 'Synopsis.txt']);
end;

function TChapter.GetDisplayTitle: string;
begin
  Result := IntToStr(OrderIndex + 1) + '. ' + Title;
end;

function TChapter.GetDisplayTitleInStory: string;
begin
  Result := DisplayTitle;
end;

function TChapter.GetDisplayTitleInProject: string;
begin
  Result := DisplayTitleInStory;
  if Story <> nil then
    Result := IntToStr(Story.OrderIndex + 1) + '.' + Result;
end;

procedure TChapter.Load;
var
  I: Integer;
  S: TScene;
begin
  if FileExists(SynopsisFilePath) then
    fSynopsis := Sys.LoadFromFile(SynopsisFilePath);

  for I := 0 to fSceneList.Count - 1 do
  begin
    S := fSceneList[I];
    S.Chapter := Self;
    S.Load;
  end;
end;

procedure TChapter.Save;
var
  I: Integer;
begin
  Sys.CreateFolders(FolderPath);
  Sys.SaveToFile(SynopsisFilePath, Synopsis);

  for I := 0 to fSceneList.Count - 1 do
    fSceneList[I].Save;
end;

procedure TChapter.SaveSynopsis;
begin
  Sys.CreateFolders(FolderPath);
  Sys.SaveToFile(SynopsisFilePath, Synopsis);
end;

procedure TChapter.Delete;
var
  I: Integer;
  C: TChapter;
begin
  if DirectoryExists(FolderPath) then
    Sys.FolderDelete(FolderPath);

  if (Story <> nil) and (Story.Project <> nil) and Assigned(Story.ChapterList) then
  begin
    for I := 0 to Story.ChapterList.Count - 1 do
      Story.ChapterList[I].FolderPathChanging;

    Story.ChapterList.Delete(Index);

    for I := 0 to Story.ChapterList.Count - 1 do
    begin
      C := Story.ChapterList[I];
      C.FolderPathChanged;
    end;

    Story.Project.SaveJson;
  end;
end;

function TChapter.CanMove(Up: Boolean): Boolean;
begin
  Result := CanMoveInCollection(Self, Up);
end;

function TChapter.Move(Up: Boolean): Boolean;
var
  I: Integer;
  C: TChapter;
begin
  Result := False;
  if (Story = nil) or (Story.Project = nil) or (not CanMove(Up)) then Exit;

  for I := 0 to Story.ChapterList.Count - 1 do
    Story.ChapterList[I].FolderPathChanging;

  Result := MoveInCollection(Self, Up);

  for I := 0 to Story.ChapterList.Count - 1 do
  begin
    C := Story.ChapterList[I];
    C.FolderPathChanged;
  end;

  Story.Project.SaveJson;
end;

procedure TChapter.ChangeParent(NewStory: TStory);
begin
  FolderPathChanging;

  if Story <> nil then
    Story.ChapterList.Delete(Index);

  if NewStory <> nil then
  begin
    // move to end of new story
    Collection := NewStory.ChapterList;
    Story := NewStory;
  end
  else
    Story := nil;

  FolderPathChanged;
end;

procedure TChapter.FolderPathChanging;
begin
  fLastFolderPath := FolderPath;
end;

procedure TChapter.FolderPathChanged;
var
  ParentFolder: string;
begin
  if (fLastFolderPath <> FolderPath) and DirectoryExists(fLastFolderPath) then
  begin
    ParentFolder := ExtractFileDir(FolderPath);
    if not DirectoryExists(ParentFolder) then
      Sys.CreateFolders(ParentFolder);

    RenameFile(fLastFolderPath, FolderPath);

    if (Story <> nil) and (Story.Project <> nil) then
      Story.Project.SaveJson;
  end;
end;

function TChapter.CountSceneTitle(const SceneTitle: string): Integer;
var
  I: Integer;
  S: TScene;
begin
  Result := 0;
  for I := 0 to fSceneList.Count - 1 do
  begin
    S := fSceneList[I];
    if Sys.IsSameText(S.Title, SceneTitle) then
      Inc(Result);
  end;
end;

function TChapter.AddScene(const Title: string): TScene;
begin
  Result := fSceneList.Add;
  Result.Chapter := Self;
  Result.Title := Title;
  if (Story <> nil) and (Story.Project <> nil) then
    Story.Project.SaveJson;
end;

function TChapter.SynopsisContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean;
begin
  if WholeWordOnly then
    Result := App.ContainsWord(Synopsis, Term)
  else
    Result := App.ContainsText(Synopsis, Term);
end;

function TChapter.SceneCount: Integer;
begin
  Result := fSceneList.Count;
end;

function TChapter.SceneAt(Index: Integer): TScene;
begin
  Result := fSceneList[Index];
end;

{ TScene }

constructor TScene.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  fSynopsis := '';
  fText := '';
  fTextEn := '';
  fTimeline := '';
end;

function TScene.GetItemType: TItemType;
begin
  Result := itScene;
end;

function TScene.GetTitle: string;
begin
  Result := fTitle;
end;

procedure TScene.SetTitle(const Value: string);
var
  NewFolder: string;
begin
  App.CheckValidFileName(Value);

  if (Chapter = nil) or (Chapter.Story = nil) or (Chapter.Story.Project = nil) or Chapter.Story.Project.Loading then
  begin
    fTitle := Value;
    Exit;
  end;

  if not Sys.IsSameText(fTitle, Value) then
  begin
    if DirectoryExists(FolderPath) then
    begin
      NewFolder := Sys.CombinePaths([Chapter.FolderPath, IntToStr(OrderIndex + 1) + '. ' + TitleToFileName(Value, False)]);
      RenameFile(FolderPath, NewFolder);
    end;

    fTitle := Value;
    Chapter.Story.Project.SaveJson;
  end;
end;

function TScene.GetOrderIndex: Integer;
begin
  Result := Index;
end;

function TScene.GetFolderPath: string;
begin
  if Chapter = nil then Exit('');
  Result := Sys.CombinePaths([Chapter.FolderPath, IntToStr(OrderIndex + 1) + '. ' + TitleToFileName(Title, False)]);
end;

function TScene.GetSynopsisFilePath: string;
begin
  Result := Sys.CombinePaths([FolderPath, 'Synopsis.txt']);
end;

function TScene.GetTextFilePath: string;
begin
  Result := Sys.CombinePaths([FolderPath, 'Text.txt']);
end;

function TScene.GetTextEnFilePath: string;
begin
  Result := Sys.CombinePaths([FolderPath, 'TextEn.txt']);
end;

function TScene.GetTimelineFilePath: string;
begin
  Result := Sys.CombinePaths([FolderPath, 'Timeline.txt']);
end;

function TScene.GetDisplayTitle: string;
begin
  Result := IntToStr(OrderIndex + 1) + '. ' + Title;
end;

function TScene.GetDisplayTitleInStory: string;
begin
  Result := DisplayTitle;
  if Chapter <> nil then
    Result := IntToStr(Chapter.OrderIndex + 1) + '.' + Result;
end;

function TScene.GetDisplayTitleInProject: string;
begin
  Result := DisplayTitleInStory;
  if (Chapter <> nil) and (Chapter.Story <> nil) then
    Result := IntToStr(Chapter.Story.OrderIndex + 1) + '.' + Result;
end;

procedure TScene.Load;
begin
  if FileExists(TextFilePath) then
    fText := Sys.LoadFromFile(TextFilePath);

  if FileExists(TextEnFilePath) then
    fTextEn := Sys.LoadFromFile(TextEnFilePath);

  if FileExists(SynopsisFilePath) then
    fSynopsis := Sys.LoadFromFile(SynopsisFilePath);

  if FileExists(TimelineFilePath) then
    fTimeline := Sys.LoadFromFile(TimelineFilePath);
end;

procedure TScene.Save;
begin
  Sys.CreateFolders(FolderPath);

  Sys.SaveToFile(TextFilePath, Text);
  Sys.SaveToFile(TextEnFilePath, TextEn);
  Sys.SaveToFile(SynopsisFilePath, Synopsis);
  Sys.SaveToFile(TimelineFilePath, Timeline);
end;

procedure TScene.Delete;
var
  I: Integer;
  S: TScene;
begin
  if DirectoryExists(FolderPath) then
    Sys.FolderDelete(FolderPath);

  if (Chapter <> nil) and (Chapter.Story <> nil) and (Chapter.Story.Project <> nil) then
  begin
    for I := 0 to Chapter.SceneList.Count - 1 do
      Chapter.SceneList[I].FolderPathChanging;

    Chapter.SceneList.Delete(Index);

    for I := 0 to Chapter.SceneList.Count - 1 do
    begin
      S := Chapter.SceneList[I];
      S.FolderPathChanged;
    end;

    Chapter.Story.Project.SaveJson;
  end;
end;

procedure TScene.SaveSynopsis;
begin
  Sys.CreateFolders(FolderPath);
  Sys.SaveToFile(SynopsisFilePath, Synopsis);
end;

procedure TScene.SaveText;
begin
  Sys.CreateFolders(FolderPath);
  Sys.SaveToFile(TextFilePath, Text);
end;

procedure TScene.SaveTextEn;
begin
  Sys.CreateFolders(FolderPath);
  Sys.SaveToFile(TextEnFilePath, TextEn);
end;

procedure TScene.SaveTimeline;
begin
  Sys.CreateFolders(FolderPath);
  Sys.SaveToFile(TimelineFilePath, Timeline);
end;

function TScene.CanMove(Up: Boolean): Boolean;
begin
  Result := CanMoveInCollection(Self, Up);
end;

function TScene.Move(Up: Boolean): Boolean;
var
  I: Integer;
  S: TScene;
begin
  Result := False;
  if (Chapter = nil) or (Chapter.Story = nil) or (Chapter.Story.Project = nil) or (not CanMove(Up)) then Exit;

  for I := 0 to Chapter.SceneList.Count - 1 do
    Chapter.SceneList[I].FolderPathChanging;

  Result := MoveInCollection(Self, Up);

  for I := 0 to Chapter.SceneList.Count - 1 do
  begin
    S := Chapter.SceneList[I];
    S.FolderPathChanged;
  end;

  Chapter.Story.Project.SaveJson;
end;

procedure TScene.ChangeParent(NewChapter: TChapter);
begin
  FolderPathChanging;

  if Chapter <> nil then
    Chapter.SceneList.Delete(Index);

  if NewChapter <> nil then
  begin
    Collection := NewChapter.SceneList;
    Chapter := NewChapter;
  end
  else
    Chapter := nil;

  FolderPathChanged;
end;

procedure TScene.FolderPathChanging;
begin
  fLastFolderPath := FolderPath;
end;

procedure TScene.FolderPathChanged;
var
  ParentFolder: string;
begin
  if (fLastFolderPath <> FolderPath) and DirectoryExists(fLastFolderPath) then
  begin
    ParentFolder := ExtractFileDir(FolderPath);
    if not DirectoryExists(ParentFolder) then
      Sys.CreateFolders(ParentFolder);

    RenameFile(fLastFolderPath, FolderPath);

    if (Chapter <> nil) and (Chapter.Story <> nil) and (Chapter.Story.Project <> nil) then
      Chapter.Story.Project.SaveJson;
  end;
end;

function TScene.TextContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean;
begin
  if WholeWordOnly then
    Result := App.ContainsWord(Text, Term)
  else
    Result := App.ContainsText(Text, Term);
end;

function TScene.SynopsisContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean;
begin
  if WholeWordOnly then
    Result := App.ContainsWord(Synopsis, Term)
  else
    Result := App.ContainsText(Synopsis, Term);
end;

function TScene.TimelineContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean;
begin
  if WholeWordOnly then
    Result := App.ContainsWord(Timeline, Term)
  else
    Result := App.ContainsText(Timeline, Term);
end;

{ TNote }

constructor TNote.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  fText := '';
end;

function TNote.GetItemType: TItemType;
begin
  Result := itNote;
end;

function TNote.GetTitle: string;
begin
  Result := fTitle;
end;

procedure TNote.SetTitle(const Value: string);
var
  NewTextFilePath: string;
begin
  App.CheckValidFileName(Value);

  if (Project = nil) or Project.Loading then
  begin
    fTitle := Value;
    Exit;
  end;

  if not Sys.IsSameText(fTitle, Value) then
  begin
    if FileExists(TextFilePath) then
    begin
      NewTextFilePath := Sys.CombinePaths([FolderPath, IntToStr(OrderIndex + 1) + '. ' + TitleToFileName(Value, False) + '.txt']);
      RenameFile(TextFilePath, NewTextFilePath);
    end;

    fTitle := Value;
    Project.SaveJson;
  end;
end;

function TNote.GetOrderIndex: Integer;
begin
  Result := Index;
end;

function TNote.GetFolderPath: string;
begin
  if Project = nil then Exit('');
  Result := Sys.CombinePaths([Project.FolderPath, 'Notes']);
end;

function TNote.GetTextFilePath: string;
begin
  Result := Sys.CombinePaths([FolderPath, IntToStr(OrderIndex + 1) + '. ' + TitleToFileName(Title, False) + '.txt']);
end;

function TNote.GetDisplayTitle: string;
begin
  Result := IntToStr(OrderIndex + 1) + '. ' + Title;
end;

function TNote.GetDisplayTitleInStory: string;
begin
  Result := DisplayTitle;
end;

function TNote.GetDisplayTitleInProject: string;
begin
  Result := DisplayTitle;
end;

procedure TNote.Load;
begin
  if FileExists(TextFilePath) then
    fText := Sys.ReadUtf8TextFile(TextFilePath);
end;

procedure TNote.Save;
begin
  Sys.CreateFolders(FolderPath);
  Sys.WriteUtf8TextFile(TextFilePath, Text);
end;

procedure TNote.Delete;
var
  I: Integer;
  N: TNote;
begin
  if FileExists(TextFilePath) then
    SysUtils.DeleteFile(TextFilePath);

  if Project <> nil then
  begin
    for I := 0 to Project.NoteList.Count - 1 do
      Project.NoteList[I].FilePathChanging;

    Project.NoteList.Delete(Index);

    for I := 0 to Project.NoteList.Count - 1 do
    begin
      N := Project.NoteList[I];
      N.FilePathChanged;
    end;

    Project.SaveJson;
  end;
end;

function TNote.CanMove(Up: Boolean): Boolean;
begin
  Result := CanMoveInCollection(Self, Up);
end;

function TNote.Move(Up: Boolean): Boolean;
var
  I: Integer;
  N: TNote;
begin
  Result := False;
  if (Project = nil) or (not CanMove(Up)) then Exit;

  for I := 0 to Project.NoteList.Count - 1 do
    Project.NoteList[I].FilePathChanging;

  Result := MoveInCollection(Self, Up);

  for I := 0 to Project.NoteList.Count - 1 do
  begin
    N := Project.NoteList[I];
    N.FilePathChanged;
  end;

  Project.SaveJson;
end;

procedure TNote.FilePathChanging;
begin
  fLastTextFilePath := TextFilePath;
end;

procedure TNote.FilePathChanged;
begin
  if (fLastTextFilePath <> TextFilePath) and FileExists(fLastTextFilePath) then
    RenameFile(fLastTextFilePath, TextFilePath);
end;

function TNote.TextContainsTerm(const Term: string; WholeWordOnly: Boolean): Boolean;
begin
  if WholeWordOnly then
    Result := App.ContainsWord(Text, Term)
  else
    Result := App.ContainsText(Text, Term);
end;

{ TCollectionBase }

function TCollectionBase.GetFirst: TCollectionItem;
begin
  Result := nil;
  if Self.Count > 0 then
    Result := Items[0];
end;

function TCollectionBase.GetLast: TCollectionItem;
begin
  Result := nil;
  if Self.Count > 0 then
    Result := Items[Self.Count - 1];
end;

function TCollectionBase.IndexOf(Item: TCollectionItem): Integer;
var
  I: Integer;
begin
  Result := -1;
  if Item = nil then
    Exit;

  for I := 0 to Count - 1 do
    if Items[I] = Item then
      Exit(I);
end;

function TCollectionBase.Remove(Item: TCollectionItem): Boolean;
begin
  Result := IndexOf(Item) >= 0;
  if Result then
    Item.Free;
end;

function TCollectionBase.FindItem(Func: TCollectionFindMethod): TCollectionItem;
var
  I: Integer;
  Item: TCollectionItem;
begin
  Result := nil;

  for I := 0 to Count - 1 do
  begin
    Item := Items[I];
    if Func(Item) then
      Exit(Item);
  end;
end;

function TCollectionBase.FindItem(Func: TCollectionFindFunc): TCollectionItem;
var
  I: Integer;
  Item: TCollectionItem;
begin
  Result := nil;

  for I := 0 to Count - 1 do
  begin
    Item := Items[I];
    if Func(Item) then
      Exit(Item);
  end;
end;

{ TProject }

function TProject.GetId: string;
begin
  if Sys.IsEmpty(fId) then
    fId := Sys.GenId(False);
  Result := fId;
end;

constructor TProject.Create;
begin
  inherited Create;
  fLoading := False;
  fFolderPath := '';
  fTempText := '';
  fMarkdownTempText := '';

  fStoryList := TStoryCollection.Create;
  fComponentList := TSWComponentCollection.Create;
  fNoteList := TNoteCollection.Create;
  fQuickView := TQuickView.Create();
end;

destructor TProject.Destroy;
begin
  fQuickView.Free;
  fNoteList.Free;
  fComponentList.Free;
  fStoryList.Free;
  inherited Destroy;
end;

function TProject.GetAllChapters: TList;
var
  i, j: Integer;
  S: TStory;
  C: TChapter;
begin
  Result := TList.Create;

  for i := 0 to StoryList.Count - 1 do
  begin
    S := StoryList[i];
    for j := 0 to S.ChapterList.Count - 1 do
    begin
      C := S.ChapterList[j];
      Result.Add(C);
    end;
  end;
end;

function TProject.GetAllScenes: TList;
var
  i, j: Integer;
  Chapters: TList;
  C: TChapter;
  Sc: TScene;
begin
  Result := TList.Create;

  Chapters := GetAllChapters;
  try
    for i := 0 to Chapters.Count - 1 do
    begin
      C := TChapter(Chapters[i]);
      for j := 0 to C.SceneList.Count - 1 do
      begin
        Sc := C.SceneList[j];
        Result.Add(Sc);
      end;
    end;
  finally
    Chapters.Free;
  end;
end;

function TProject.FindComponentById(const Id: string): TSWComponent;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to ComponentList.Count - 1 do
    if ComponentList[i].Id = Id then Exit(ComponentList[i]);
end;

function TProject.FindNoteById(const Id: string): TNote;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to NoteList.Count - 1 do
    if NoteList[i].Id = Id then Exit(NoteList[i]);
end;

function TProject.FindChapterById(const Id: string): TChapter;
var
  L: TList;
  i: Integer;
begin
  Result := nil;
  L := GetAllChapters;
  try
    for i := 0 to L.Count - 1 do
      if TChapter(L[i]).Id = Id then Exit(TChapter(L[i]));
  finally
    L.Free;
  end;
end;

function TProject.FindSceneById(const Id: string): TScene;
var
  L: TList;
  i: Integer;
begin
  Result := nil;
  L := GetAllScenes;
  try
    for i := 0 to L.Count - 1 do
      if TScene(L[i]).Id = Id then Exit(TScene(L[i]));
  finally
    L.Free;
  end;
end;

function TProject.GetImagesFolderPath: string;
begin
  Result := Sys.CombinePaths([FolderPath, ImagesFolderName]);
end;

function TProject.GetComponentsFolderPath: string;
begin
  Result := Sys.CombinePaths([FolderPath, ComponentsFolderName]);
end;

function TProject.GetComponentsFolderPathEn: string;
begin
  Result := Sys.CombinePaths([FolderPath, ComponentsFolderNameEn]);
end;

function TProject.GetWikiFolderPath: string;
begin
  Result := Sys.CombinePaths([FolderPath, WikiFolderName]);
end;

function TProject.GetWikiFolderPathEn: string;
begin
  Result := Sys.CombinePaths([FolderPath, WikiFolderNameEn]);
end;

function TProject.GetProjectFilePath: string;
begin
  Result := Sys.CombinePaths([FolderPath, 'Project.json']);
end;

function TProject.GetTempFilePath: string;
begin
  Result := Sys.CombinePaths([FolderPath, 'Temp.txt']);
end;

function TProject.GetMarkdownTempFilePath: string;
begin
  Result := Sys.CombinePaths([FolderPath, 'MarkdownTemp.md']);
end;

function TProject.GetQuickViewListFilePath: string;
begin
  Result := Sys.CombinePaths([FolderPath, 'QuickView.json']);
end;

procedure TProject.Load;
var
  I, J, K: Integer;
  C: TSWComponent;
  N: TNote;
  S: TStory;
  Ch: TChapter;
  Sc: TScene;
begin
  if not FileExists(ProjectFilePath) then
    Sys.Error('File not found: %s', [ProjectFilePath]);

  fLoading := True;
  try
    Json.LoadFromFile(ProjectFilePath, Self);

    for I := 0 to ComponentList.Count - 1 do
    begin
      C := ComponentList[I];
      C.Project := Self;
      C.Load;
    end;

    for I := 0 to NoteList.Count - 1 do
    begin
      N := NoteList[I];
      N.Project := Self;
    end;
    for I := 0 to NoteList.Count - 1 do
      NoteList[I].Load;

    for I := 0 to StoryList.Count - 1 do
    begin
      S := StoryList[I];
      S.Project := Self;

      for J := 0 to S.ChapterList.Count - 1 do
      begin
        Ch := S.ChapterList[J];
        Ch.Story := S;

        for K := 0 to Ch.SceneList.Count - 1 do
        begin
          Sc := Ch.SceneList[K];
          Sc.Chapter := Ch;
        end;
      end;
    end;

    for I := 0 to StoryList.Count - 1 do
      StoryList[I].Load;

    if FileExists(TempFilePath) then
      fTempText := Sys.LoadFromFile(TempFilePath);

    if FileExists(MarkdownTempFilePath) then
      fMarkdownTempText := Sys.LoadFromFile(MarkdownTempFilePath);
  finally
    fLoading := False;
  end;
end;

procedure TProject.Save;
var
  I: Integer;
begin
  SaveJson;
  SaveTempText;

  for I := 0 to ComponentList.Count - 1 do
    ComponentList[I].Save;

  for I := 0 to StoryList.Count - 1 do
    StoryList[I].Save;

  for I := 0 to NoteList.Count - 1 do
    NoteList[I].Save;
end;

procedure TProject.SaveJson;
begin
  if not DirectoryExists(ImagesFolderPath) then
    Sys.CreateFolders(ImagesFolderPath);

  if not DirectoryExists(FolderPath) then
    Sys.CreateFolders(FolderPath);

  Json.SaveToFile(ProjectFilePath, Self);
end;

procedure TProject.SaveTempText;
begin
  Sys.CreateFolders(FolderPath);
  Sys.SaveToFile(TempFilePath, TempText);
end;

procedure TProject.SaveMarkdownTempText;
begin
  Sys.CreateFolders(FolderPath);
  Sys.SaveToFile(MarkdownTempFilePath, MarkdownTempText);
end;

function TProject.CountStoryTitle(const StoryTitle: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to StoryList.Count - 1 do
    if Sys.IsSameText(StoryList[I].Title, StoryTitle) then
      Inc(Result);
end;

function TProject.CountNoteTitle(const NoteTitle: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to NoteList.Count - 1 do
    if Sys.IsSameText(NoteList[I].Title, NoteTitle) then
      Inc(Result);
end;

function TProject.CountComponentTitle(const ComponentTitle: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ComponentList.Count - 1 do
    if Sys.IsSameText(ComponentList[I].Title, ComponentTitle) then
      Inc(Result);
end;

function TProject.AddStory(const Title: string): TStory;
begin
  Result := StoryList.Add;
  Result.Project := Self;
  Result.Title := Title;
  SaveJson;
end;

function TProject.AddNote(const Title: string; const NoteText: string): TNote;
begin
  Result := NoteList.Add;
  Result.Project := Self;
  Result.Title := Title;
  SaveJson;
  Result.Text := NoteText;
  Result.Save;
end;

function TProject.AddComponent(const Title: string): TSWComponent;
begin
  Result := ComponentList.Add;
  Result.Title := Title;
  AddComponent(Result);
end;

function TProject.AddComponent(AComponent: TSWComponent): TSWComponent;
begin
  Result := AComponent;
  Result.Collection := ComponentList;
  Result.Project := Self;
  SaveJson;
end;

function TProject.GetCategoryList(SourceList: TSWComponentCollection): TStrings;
var
  i : Integer;
  StringList : TStringList;
begin
  if not Assigned(SourceList) then
    SourceList := Self.ComponentList;

  StringList := TStringList.Create();
  StringList.Duplicates := dupIgnore;
  StringList.Sorted := True;
  StringList.CaseSensitive := False;

  for i := 0 to SourceList.Count - 1 do
    if Trim(SourceList[i].Category) <> '' then
      StringList.Add(SourceList[i].Category);

  Result := StringList;
end;

function TProject.GetTagList(SourceList: TSWComponentCollection): TStrings;
var
  i : Integer;
  j : Integer;
  StringList : TStringList;
begin
  if not Assigned(SourceList) then
    SourceList := Self.ComponentList;

  StringList := TStringList.Create();
  StringList.Duplicates := dupIgnore;
  StringList.Sorted := True;
  StringList.CaseSensitive := False;

  for i := 0 to SourceList.Count - 1 do
    for j := 0 to SourceList[i].TagList.Count - 1 do
        if Trim(SourceList[i].TagList[j]) <> '' then
          StringList.Add(SourceList[i].TagList[j]);

  Result := StringList;
end;

function TProject.GetComponentList(): TObjectList;
var
  i : Integer;
  StringList : TStringList;
begin
  StringList := TStringList.Create();
  StringList.Duplicates := dupIgnore;
  StringList.Sorted := True;
  StringList.CaseSensitive := False;

  for i := 0 to ComponentList.Count - 1 do
    if (Trim(ComponentList[i].Category) <> '') and (Trim(ComponentList[i].Title) <> '') then
      StringList.AddObject(ComponentList[i].Category + '#1' + ComponentList[i].Title, ComponentList[i]);           // (SourceList[i].Title);

  Result := TObjectList.Create(False);
  for i := 0 to StringList.Count - 1 do
    Result.Add(StringList.Objects[i]);
end;

function TProject.CategoryExists(const Category: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to ComponentList.Count - 1 do
    if Sys.IsSameText(ComponentList[I].Category, Category) then
      Exit(True);
end;

function TProject.TagExists(const Tag: string): Boolean;
var
  I, J: Integer;
  C: TSWComponent;
begin
  Result := False;
  for I := 0 to ComponentList.Count - 1 do
  begin
    C := ComponentList[I];
    for J := 0 to C.TagList.Count - 1 do
      if Sys.IsSameText(C.TagList[J], Tag) then
        Exit(True);
  end;
end;

function TProject.StoryCount: Integer;
begin
  Result := StoryList.Count;
end;

function TProject.StoryAt(Index: Integer): TStory;
begin
  Result := StoryList[Index];
end;

function TProject.ComponentCount: Integer;
begin
  Result := ComponentList.Count;
end;

function TProject.ComponentAt(Index: Integer): TSWComponent;
begin
  Result := ComponentList[Index];
end;

function TProject.NoteCount: Integer;
begin
  Result := NoteList.Count;
end;

function TProject.NoteAt(Index: Integer): TNote;
begin
  Result := NoteList[Index];
end;

function TProject.GetComponentListText(): string;
var
  List: TStringList;
  i : Integer;
  S : string;
begin
  Result := '';

  List := TStringList.Create();
  try
    for i := 0 to ComponentList.Count - 1 do
    begin
      S := Format('%s - %s', [ComponentList[i].Title, ComponentList[i].Category]);
      List.Add(S);
    end;

    Result := List.Text;
  finally
    List.Free;
  end;

end;

function TProject.GlobalSearch(const Term: string): TLinkItemList;
begin
  Result := TProjectGlobalSearch.Execute(Self, Term);
end;


{ TLinkItem }

constructor TLinkItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  fItemType := TItemType.itNone;
  fPlace := lpTitle;
  fIsEnglish := False;
end;

constructor TLinkItem.Create(ACollection: TCollection; AType: TItemType; APlace: TLinkPlace; const ATitle: string; AItem: TBaseItem);
begin
  Create(ACollection);
  Title := ATitle;
  fPlace := APlace;
  fItem := AItem;
  fItemType := AType;
end;

function TLinkItem.ToString: string;
begin
  Result := Format('%s - %s', [ItemTypeToString(fItemType), Title]);
end;

procedure TLinkItem.LoadItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  case Self.ItemType of
    itComponent: fItem := App.CurrentProject.FindComponentById(Id);
    itChapter  : fItem := App.CurrentProject.FindChapterById(Id);
    itScene    : fItem := App.CurrentProject.FindSceneById(Id);
    itNote     : fItem := App.CurrentProject.FindNoteById(Id);
  else
    fItem := nil;
  end;
end;

function TLinkItem.CanMove(Up: Boolean): Boolean;
begin
  Result := TBaseItem.CanMoveInCollection(Self, Up);
end;

function TLinkItem.Move(Up: Boolean): Boolean;
begin
  Result := False;

  if (App.CurrentProject = nil) or (not CanMove(Up)) then
  Exit;

  Result := TBaseItem.MoveInCollection(Self, Up);
  if Result then
  begin
    App.CurrentProject.QuickView.Save();
  end;
end;

function TLinkItem.GetId: string;
begin
  if (Trim(fId) = '') and Assigned(fItem) then
    fId := fItem.Id;
  Result := fId;
end;

procedure TLinkItem.SetId(const AValue: string);
begin
  fId := AValue;
end;

function TLinkItem.GetTitle: string;
begin
  if Assigned(fItem) then
    Result := fItem.Title
  else
    Result := fTitle;
end;

procedure TLinkItem.SetTitle(const AValue: string);
begin
  fTitle := AValue;
end;

{ TLinkItemList }

constructor TLinkItemList.Create(AOwner: TPersistent);
begin
  inherited Create(TLinkItem);
  fOwner := AOwner;
end;

function TLinkItemList.FindById(const Id: string): TLinkItem;
var
  Item: TCollectionItem;
begin
  Result := nil;
  for Item in Self do
  begin
    if AnsiSameText(Id, TLinkItem(Item).Id) then
    begin
      Result := TLinkItem(Item);
      break;
    end;
  end;
end;

function TLinkItemList.GetOwner: TPersistent;
begin
  Result := fOwner;
end;

function TLinkItemList.Add: TLinkItem;
begin
  Result := TLinkItem(inherited Add);
end;

function TLinkItemList.GetItem(Index: Integer): TLinkItem;
var
  Item: TCollectionItem;
begin
  Item := inherited Items[Index];
  Result := TLinkItem(Item);
end;

procedure TLinkItemList.SetItem(Index: Integer; const Value: TLinkItem);
begin
  inherited Items[Index] := Value;
end;

{ TQuickView }

constructor TQuickView.Create();
begin
  inherited Create;
  FList := TLinkItemList.Create(Self);
end;

destructor TQuickView.Destroy();
begin
  FList.Free();
  inherited Destroy();
end;

function TQuickView.FindById(const Id: string): TLinkItem;
begin
  Result := FList.FindById(Id);
end;

procedure TQuickView.Clear();
begin
  FList.Clear;
end;

procedure TQuickView.ClearAndSave();
begin
  Clear();
  Save();
end;

procedure TQuickView.Save();
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Json.SaveToFile(App.CurrentProject.QuickViewListFilePath, Self);
end;

procedure TQuickView.Load();
var
  FilePath: string;
  ListCount, i: Integer;
  ListToDelete: TObjectList;
begin
  Clear();

  if not Assigned(App.CurrentProject) then
    Exit;

  FilePath := App.CurrentProject.QuickViewListFilePath;

  if not FileExists(FilePath) then
    Exit;

  Self.Clear();
  Json.LoadFromFile(FilePath, Self);

  // load items
  ListToDelete := TObjectList.Create(False);
  try
    ListCount := List.Count;

    for i := 0 to List.Count - 1 do
    begin
      List[i].LoadItem();
      if not Assigned(List[i].Item) then
        ListToDelete.Add(List[i]);
    end;

    for i := 0 to ListToDelete.Count - 1 do
      List[i].Free();

    // if needs saving, save the list
    if ListCount <> List.Count then
      Save();
  finally
    ListToDelete.Free();
  end;

end;


end.

