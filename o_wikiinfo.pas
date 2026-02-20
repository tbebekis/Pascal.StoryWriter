unit o_WikiInfo;

{$MODE Delphi}{$H+}

interface

uses
  SysUtils
  , Classes
  , Generics.Collections
  , Generics.Defaults
  ,o_Entities
  ;

type
  { Forward declarations }
  TComponentInfo = class;
  TComponentCategory = class;
  TComponentTag = class;

  { TWikiBuildInfo }

  TWikiBuildInfo = class
  private
    FInEnglish: Boolean;
    FComponentsFolderPath: string;
    FImagesFolderPath: string;
    FOutputFolderPath: string;
    FWorldComponentTitle: string;
    FGenerateTagPages: Boolean;
    FComponents: TObjectList<TComponentInfo>;
    FCategories: TObjectList<TComponentCategory>;
    FTags: TObjectList<TComponentTag>;
    FSiteBaseUrl: string;
    FDefaultSocialImageUrl: string;
  public
    constructor Create(AInEnglish: Boolean);
    destructor Destroy; override;

    property InEnglish: Boolean read FInEnglish write FInEnglish;
    property ComponentsFolderPath: string read FComponentsFolderPath write FComponentsFolderPath;
    property ImagesFolderPath: string read FImagesFolderPath write FImagesFolderPath;
    property OutputFolderPath: string read FOutputFolderPath write FOutputFolderPath;
    property WorldComponentTitle: string read FWorldComponentTitle write FWorldComponentTitle;
    property GenerateTagPages: Boolean read FGenerateTagPages write FGenerateTagPages;

    property Components: TObjectList<TComponentInfo> read FComponents;
    property Categories: TObjectList<TComponentCategory> read FCategories;
    property Tags: TObjectList<TComponentTag> read FTags;

    property SiteBaseUrl: string read FSiteBaseUrl write FSiteBaseUrl;
    property DefaultSocialImageUrl: string read FDefaultSocialImageUrl write FDefaultSocialImageUrl;
  end;

  { TComponentInfo }

  TComponentInfo = class
  private
    FTitle: string;
    FCategory: string;
    FAliasList: TStringList;
    FTagList: TStringList;
  public
    constructor Create(Source: TSWComponent = nil);
    destructor Destroy; override;

    property Title: string read FTitle write FTitle;
    property Category: string read FCategory write FCategory;
    property AliasList: TStringList read FAliasList;
    property TagList: TStringList read FTagList;
  end;

  { TComponentCategory }

  TComponentCategory = class
  private
    FName: string;
    FComponents: TObjectList<TComponentInfo>;
  public
    constructor Create(const Category: string; SourceComponents: TObjectList<TComponentInfo>);
    destructor Destroy; override;

    property Name: string read FName write FName;
    property Components: TObjectList<TComponentInfo> read FComponents;
  end;

  { TComponentTag }

  TComponentTag = class
  private
    FName: string;
    FComponents: TObjectList<TComponentInfo>;
  public
    constructor Create(const Tag: string; SourceComponents: TObjectList<TComponentInfo>);
    destructor Destroy; override;

    property Name: string read FName write FName;
    property Components: TObjectList<TComponentInfo> read FComponents;
  end;

  { TWikiBuildResult }

  TWikiBuildResult = class
  private
    FEmittedFiles: TStringList;
    FLog: TStringList;
  public
    constructor Create;
    destructor Destroy; override;

    property EmittedFiles: TStringList read FEmittedFiles;
    property Log: TStringList read FLog;
  end;

  { TSearchIndexEntry }

  TSearchIndexEntry = class
  private
    FId: string;
    FTitle: string;
    FAliases: TStringList;
    FTags: TStringList;
    FBody: string;
    FUrl: string;
    FCategory: string;
  public
    constructor Create;
    destructor Destroy; override;

    property Id: string read FId write FId;
    property Title: string read FTitle write FTitle;
    property Aliases: TStringList read FAliases;
    property Tags: TStringList read FTags;
    property Body: string read FBody write FBody;
    property Url: string read FUrl write FUrl;
    property Category: string read FCategory write FCategory;
  end;




implementation

uses
   o_App

  ;



{ TWikiBuildInfo }

constructor TWikiBuildInfo.Create(AInEnglish: Boolean);
var
  SourceComponentList: TObjectList<TSWComponent>;
  Item: TCollectionItem;
  ComponentInfo: TComponentInfo;
  ComponentCategory: TComponentCategory;
  ComponentTag: TComponentTag;
  CategoryNamesList: TStringList;
  TagNamesList: TStringList;
  S : string;
begin
  inherited Create;
  FInEnglish := AInEnglish;
  FGenerateTagPages := True;

  FComponents := TObjectList<TComponentInfo>.Create(True);
  FCategories := TObjectList<TComponentCategory>.Create(True);
  FTags := TObjectList<TComponentTag>.Create(True);

  // ● components
  SourceComponentList := TObjectList<TSWComponent>.Create(False);
  CategoryNamesList := TStringList.Create;
  CategoryNamesList.Sorted := True;
  CategoryNamesList.Duplicates := dupIgnore;

  TagNamesList := TStringList.Create;
  TagNamesList.Sorted := True;
  TagNamesList.Duplicates := dupIgnore;
  try
    if InEnglish then
    begin
      for Item in App.CurrentProject.ComponentList do
        if Trim(TSWComponent(Item).TextEn) <> '' then
           SourceComponentList.Add(TSWComponent(Item));
    end else begin
      for Item in App.CurrentProject.ComponentList do
        SourceComponentList.Add(TSWComponent(Item));
    end;

    for Item in SourceComponentList do
    begin
      ComponentInfo := TComponentInfo.Create(TSWComponent(Item));
      Components.Add(ComponentInfo);

      CategoryNamesList.Add(ComponentInfo.Category);

      for S in ComponentInfo.TagList do
        TagNamesList.Add(S);
    end;

    // ● categories
    for S in CategoryNamesList do
    begin
      ComponentCategory := TComponentCategory.Create(S, Components);
      Categories.Add(ComponentCategory);
    end;

    // ● tags
    for S in TagNamesList do
    begin
      ComponentTag := TComponentTag.Create(S, Components);
      Tags.Add(ComponentTag);
    end;

  finally
    TagNamesList.Free();
    CategoryNamesList.Free();
    SourceComponentList.Free();
  end;

  // ● properties
  if InEnglish then
  begin
    ComponentsFolderPath := App.CurrentProject.ComponentsFolderPathEn;
    OutputFolderPath := App.CurrentProject.WikiFolderPathEn;
  end
  else begin
    ComponentsFolderPath := App.CurrentProject.ComponentsFolderPath;
    OutputFolderPath := App.CurrentProject.WikiFolderPath;
  end;

  ImagesFolderPath := App.CurrentProject.ImagesFolderPath;
  WorldComponentTitle := 'World';
  GenerateTagPages := True;
  SiteBaseUrl := 'https://wiki.thecorpofworld.com';
  DefaultSocialImageUrl := '/assets/images/world-cover.jpg';

end;

destructor TWikiBuildInfo.Destroy;
begin
  FComponents.Free;
  FCategories.Free;
  FTags.Free;
  inherited;
end;

{ TComponentInfo }

constructor TComponentInfo.Create(Source: TSWComponent);
begin
  inherited Create;
  FAliasList := TStringList.Create;
  FTagList := TStringList.Create;

  if Assigned(Source) then
  begin
    Title := Source.Title;
    Category := Source.Category;
    AliasList.AddStrings(Source.AliasList);
    TagList.AddStrings(Source.TagList);
  end;
end;

destructor TComponentInfo.Destroy;
begin
  FAliasList.Free;
  FTagList.Free;
  inherited;
end;

{ TComponentCategory }

constructor TComponentCategory.Create(const Category: string; SourceComponents: TObjectList<TComponentInfo>);
var
  ComponentInfo: TComponentInfo;
begin
  inherited Create;
  FComponents := TObjectList<TComponentInfo>.Create(False); // no ownership
  Name := Category;

  for ComponentInfo in SourceComponents do
    if AnsiSameText(Name, ComponentInfo.Category) then
      Components.Add(ComponentInfo);
end;

destructor TComponentCategory.Destroy;
begin
  FComponents.Free;
  inherited;
end;

{ TComponentTag }

constructor TComponentTag.Create(const Tag: string; SourceComponents: TObjectList<TComponentInfo>);
var
  ComponentInfo: TComponentInfo;
begin
  inherited Create;
  FComponents := TObjectList<TComponentInfo>.Create(False); // no ownership
  Name := Tag;

  for ComponentInfo in SourceComponents do
    if ComponentInfo.TagList.IndexOf(Tag) <> -1 then
      Components.Add(ComponentInfo);
end;

destructor TComponentTag.Destroy;
begin
  FComponents.Free;
  inherited;
end;

{ TWikiBuildResult }

constructor TWikiBuildResult.Create;
begin
  inherited Create;
  FEmittedFiles := TStringList.Create;
  FLog := TStringList.Create;
end;

destructor TWikiBuildResult.Destroy;
begin
  FEmittedFiles.Free;
  FLog.Free;
  inherited;
end;

{ TSearchIndexEntry }

constructor TSearchIndexEntry.Create;
begin
  inherited Create;
  FId := '';
  FTitle := '';
  FAliases := TStringList.Create;
  FTags := TStringList.Create;
  FBody := '';
  FUrl := '';
  FCategory := '';
end;

destructor TSearchIndexEntry.Destroy;
begin
  FAliases.Free;
  FTags.Free;
  inherited;
end;

end.
