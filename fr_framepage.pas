unit fr_FramePage;

{$MODE DELPHI}{$H+}
{$WARN 5024 off : Parameter "$1" not used}

interface

uses
  Classes
  , SysUtils
  , Forms
  , ComCtrls
  , Controls
  , LCLType
  , Tripous.Broadcaster
  , fr_TextEditor
  , o_Entities
  ;

type
  { TFramePage }
  TFramePage = class(TFrame)
  private
    fCloseableByUser: Boolean;
    fId: string;
    fInfo: TObject;
  protected
    TitleText: string;
    fBroadcasterToken: TBroadcastToken;
    function GetParentTabPage: TTabSheet; virtual;

    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); virtual;

    // ● App Events
    procedure AppOnProjectOpened(Args: TBroadcasterArgs); virtual;
    procedure AppOnProjectClosed(Args: TBroadcasterArgs); virtual;
    procedure AppOnItemListChanged(Args: TBroadcasterArgs); virtual;
    procedure AppOnItemChanged(Args: TBroadcasterArgs); virtual;
    procedure AppOnSearchTermIsSet(Args: TBroadcasterArgs); virtual;
    procedure AppOnCategoryListChanged(Args: TBroadcasterArgs); virtual;
    procedure AppOnTagListChanged(Args: TBroadcasterArgs); virtual;
    procedure AppOnComponentListChanged(Args: TBroadcasterArgs); virtual;
    procedure AppOnProjectMetricsChanged(Args: TBroadcasterArgs); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ControlInitialize(); virtual;
    procedure ControlInitializeAfter(); virtual;
    procedure Close(); virtual;

    procedure TitleChanged(); virtual;
    procedure AdjustTabTitle(); virtual;


    // ● editor handler
    procedure EditorModifiedChanged(TextEditor: TfrTextEditor); virtual;
    procedure SaveEditorText(TextEditor: TfrTextEditor); virtual;
    procedure GlobalSearchForTerm(const Term: string); virtual;

    procedure HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean); virtual;

    // ● toolbar
    function AddButton(AToolBar: TToolBar; const AIconName: string; const AHint: string; AOnClick: TNotifyEvent): TToolButton;
    function AddSeparator(AToolBar: TToolBar): TToolButton;

    // ● properties
    property Id : string read fId write fId;
    property CloseableByUser: Boolean read fCloseableByUser write fCloseableByUser;
    property Info: TObject read fInfo write fInfo;

    property ParentTabPage: TTabSheet read GetParentTabPage;
  end;

implementation

{$R *.lfm}

uses
   Tripous.IconList
  ,o_Consts
  ,o_App
  ;

{ TFramePage }

constructor TFramePage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fBroadcasterToken := Broadcaster.Register(OnBroadcasterEvent);
end;

destructor TFramePage.Destroy;
begin
  Broadcaster.Unregister(fBroadcasterToken);
  inherited Destroy;
end;

procedure TFramePage.ControlInitialize();
begin

end;

procedure TFramePage.ControlInitializeAfter();
begin

end;

function TFramePage.GetParentTabPage: TTabSheet;
begin
  if Self.Parent is TTabSheet then
     Result := Self.Parent as TTabSheet
  else
    Result := nil;
end;

procedure TFramePage.TitleChanged();
begin
  AdjustTabTitle();
end;

procedure TFramePage.AdjustTabTitle();
begin
end;

procedure TFramePage.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekProjectOpened : AppOnProjectOpened(Args);
    aekProjectClosed : AppOnProjectClosed(Args);
    aekItemListChanged: AppOnItemListChanged(Args);     // (TItemType(TBroadcasterIntegerArgs(Args).Value));
    aekItemChanged: AppOnItemChanged(Args);             // (TBaseItem(Args.Data));
    aekSearchTermIsSet: AppOnSearchTermIsSet(Args);     // (string(TBroadcasterTextArgs(Args).Value));
    aekCategoryListChanged: AppOnCategoryListChanged(Args);
    aekTagListChanged: AppOnTagListChanged(Args);
    aekComponentListChanged: AppOnComponentListChanged(Args);
    aekProjectMetricsChanged: AppOnProjectMetricsChanged(Args);
  end;
end;

procedure TFramePage.Close();
begin
  //if Assigned(ParentTabPage) and Assigned(ParentTabPage.PageControl) then
  //   ParentTabPage.PageControl := nil;
end;

procedure TFramePage.EditorModifiedChanged(TextEditor: TfrTextEditor);
begin
  AdjustTabTitle();
end;

procedure TFramePage.SaveEditorText(TextEditor: TfrTextEditor);
begin
end;

procedure TFramePage.GlobalSearchForTerm(const Term: string);
begin
  // search all text documents in the application for the term
  App.SetGlobalSearchTerm(Term);
end;

procedure TFramePage.HighlightAll(LinkItem: TLinkItem; const Term: string; IsWholeWord: Boolean; MatchCase: Boolean);
begin

end;

function TFramePage.AddButton(AToolBar: TToolBar; const AIconName: string; const AHint: string; AOnClick: TNotifyEvent): TToolButton;
begin
  Result := IconList.AddButton(AToolBar, AIconName, AHint, AOnClick);
end;

function TFramePage.AddSeparator(AToolBar: TToolBar): TToolButton;
begin
  Result := IconList.AddSeparator(AToolBar);
end;

procedure TFramePage.AppOnProjectOpened(Args: TBroadcasterArgs);
begin

end;

procedure TFramePage.AppOnProjectClosed(Args: TBroadcasterArgs);
begin

end;

procedure TFramePage.AppOnItemListChanged(Args: TBroadcasterArgs);
begin

end;

procedure TFramePage.AppOnItemChanged(Args: TBroadcasterArgs);
begin

end;

procedure TFramePage.AppOnSearchTermIsSet(Args: TBroadcasterArgs);
begin

end;

procedure TFramePage.AppOnCategoryListChanged(Args: TBroadcasterArgs);
begin

end;

procedure TFramePage.AppOnTagListChanged(Args: TBroadcasterArgs);
begin

end;

procedure TFramePage.AppOnComponentListChanged(Args: TBroadcasterArgs);
begin

end;

procedure TFramePage.AppOnProjectMetricsChanged(Args: TBroadcasterArgs);
begin

end;

end.

