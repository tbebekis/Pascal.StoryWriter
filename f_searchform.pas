unit f_SearchForm;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , ExtCtrls
  , ComCtrls
  , StdCtrls
  , Contnrs
  , Menus
  , DB
  , DBCtrls
  , DBGrids
  , f_PageForm
  , Tripous.MemTable
  , Tripous.Broadcaster
  , o_Entities
  , f_TextEditorForm
  ;

type

  { TSearchForm }

  TSearchForm = class(TPageForm)
    edtSearch: TEdit;
    Label1: TLabel;
    pnlBottom: TPanel;
    pnlFilter: TPanel;
    pnlTitle: TPanel;
    pnlTop: TPanel;
    Splitter: TSplitter;
    ToolBar: TToolBar;
    tv: TTreeView;
  private
    LinkItems: TLinkItemList;

    frmText: TTextEditorForm;

    btnAddToQuickView : TToolButton;
    btnShowItemInListPage : TToolButton;
    btnExpandAll : TToolButton;
    btnCollapseAll : TToolButton;

    // ● event handler
    procedure AnyClick(Sender: TObject);

    procedure edtSearchOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure tv_OnDoubleClick(Sender: TObject);
    procedure tv_OnSelectedNodeChanged(Sender: TObject; Node: TTreeNode);

    procedure PrepareToolBar();

    procedure GlobalSearchTermChanged();
    procedure ShowLinkItemPage();
    procedure ShowItemInListPage();

    procedure AddToQuickView();

    procedure SelectedNodeChanged();

    procedure ExpandAll();
    procedure CollapseAll();

    procedure ReLoad();
    procedure ClearAll();
  protected
    procedure FormInitialize(); override;
    procedure FormInitializeAfter(); override;
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;
  end;



implementation

{$R *.lfm}


uses
   LCLType
  ,Tripous.Logs
  ,o_Consts
  ,o_App
  ,f_QuickViewForm
  ;

{ TSearchForm }

constructor TSearchForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  frmText := TTextEditorForm.Create(Self);
  frmText.Parent := pnlBottom;
end;

destructor TSearchForm.Destroy();
begin
  inherited Destroy();
end;

procedure TSearchForm.FormInitialize;
begin
  frmText.Visible := True;

  ParentTabPage.Caption := 'Search';

  PrepareToolBar();

  tv.ReadOnly := True ;

  frmText.ToolBarVisible := False;
  frmText.TextEditor.ReadOnly := True;

  edtSearch.OnKeyDown := edtSearchOnKeyDown;
  tv.OnDblClick := tv_OnDoubleClick;
  tv.OnChange  := tv_OnSelectedNodeChanged;
end;

procedure TSearchForm.FormInitializeAfter();
begin
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
end;


procedure TSearchForm.ReLoad();
var
  DocNo: Integer;
  BaseItem: TBaseItem;
  ParentNode, Node: TTreeNode;
  i: Integer;
  LI: TLinkItem;

  function ItemCaption(AItem: TLinkItem): string;
  begin
    Result := Format('%s - %s',
      [ItemTypeToString(AItem.ItemType), AItem.Item.DisplayTitleInProject]);
  end;

  function ChildCaption(AItem: TLinkItem): string;
  begin
    Result := Format('%s - (%d)',
      [LinkPlaceToString(AItem.Place), AItem.CharPos]);
  end;

begin
  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;
  try
    ClearAll;

    Application.ProcessMessages;

    if Assigned(LinkItems) then
    begin
      tv.Items.BeginUpdate;
      try
        tv.Items.Clear;

        DocNo := 0;
        BaseItem := nil;
        ParentNode := nil;

        for i := 0 to LinkItems.Count - 1 do
        begin
          LI := LinkItems.Items[i];

          if LI.Item <> BaseItem then
          begin
            Inc(DocNo);
            BaseItem := LI.Item;
            ParentNode := tv.Items.Add(nil, ItemCaption(LI));
            ParentNode.Data := LI; // αντί Tag
          end;

          Node := tv.Items.AddChild(ParentNode, ChildCaption(LI));
          Node.Data := LI;
        end;

      finally
        tv.Items.EndUpdate;
      end;
    end;

    SelectedNodeChanged;
  finally
    Application.ProcessMessages;
    Screen.Cursor := crDefault;
  end;

end;

procedure TSearchForm.ClearAll();
begin
  tv.BeginUpdate();
  try
    tv.Items.Clear();
    pnlTitle.Caption := 'No selection';
    frmText.TextEditor.EditorText := '';
  finally
    tv.EndUpdate();
  end;
end;

procedure TSearchForm.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekItemListChanged: ReLoad();        // (TItemType(TBroadcasterIntegerArgs(Args).Value));
    aekItemChanged: ReLoad();             // (TBaseItem(Args.Data));
    aekSearchTermIsSet:
    begin
      edtSearch.Text := TBroadcasterTextArgs(Args).Value;
      GlobalSearchTermChanged();
    end;
  end;
end;

procedure TSearchForm.GlobalSearchTermChanged();
var
  Msg: string;
  Term: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Term := Trim(edtSearch.Text);

  if Length(Term) > 2 then
  begin
    Msg := Format('Global search for term: "%s". Please wait...', [Term]);
    LogBox.AppendLine(Msg);

    //Wait.Show(Msg);

    Screen.Cursor := crHourGlass;
    Application.ProcessMessages;
    try
      LinkItems := App.CurrentProject.GlobalSearch(Term);

      ReLoad();

      // Select tab (αν είναι TPageControl)
      if (ParentTabPage.Parent is TPageControl) then
        TPageControl(ParentTabPage.Parent).ActivePage := ParentTabPage;
    finally
      Application.ProcessMessages;
      Screen.Cursor := crDefault;
      //Wait.ForceClose;
    end;

    Msg := Format(' Found items: %d', [LinkItems.Count]);
    LogBox.AppendLine(Msg);

    if LinkItems.Count = 0 then
    begin
      Msg := Format('No search results for "%s"', [Term]);
      LogBox.AppendLine(Msg);
      App.InfoBox(Msg);
    end;
  end
  else
  begin
    ClearAll;
  end;

end;

procedure TSearchForm.ShowLinkItemPage();
var
  Node: TTreeNode;
  LinkItem: TLinkItem;
  TabPage: TTabSheet;
  PageForm: TPageForm;
  Term: string;
  IsWholeWord: Boolean;
  MatchCase: Boolean;
begin
  Node := tv.Selected;
  if Assigned(Node) and Assigned(Node.Data) then
  begin
    LinkItem := TLinkItem(Node.Data);
    TabPage  := App.ShowLinkItemPage(LinkItem);
    if Assigned(TabPage) and (TabPage.Tag > 0)then
    begin
      TabPage.PageControl.ActivePage := TabPage;

      PageForm := TPageForm(TabPage.Tag);

      Term := App.LastGlobalSearchTerm;
      IsWholeWord := App.LastGlobalSearchTermWholeWord;
      MatchCase := IsWholeWord;

      PageForm.HighlightAll(LinkItem, Term, IsWholeWord, MatchCase);
    end;
  end;
end;

procedure TSearchForm.ShowItemInListPage();
var
  LinkItem: TLinkItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if Assigned(tv.Selected) and Assigned(tv.Selected.Data) then
  begin
    LinkItem := TLinkItem(tv.Selected.Data);
    App.ShowItemInListPage(LinkItem);
  end;

end;

procedure TSearchForm.SelectedNodeChanged();
var
  LinkItem: TLinkItem;
begin
  if Assigned(tv.Selected) and Assigned(tv.Selected.Data) then
  begin
    LinkItem := TLinkItem(tv.Selected.Data);
    App.UpdateLinkItemUi(LinkItem, pnlTitle, frmText.TextEditor);
    Application.ProcessMessages();
  end;
end;

procedure TSearchForm.PrepareToolBar();
var
  P: TWinControl;
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  P := ToolBar.Parent;
  ToolBar.Parent := nil;
  try
    btnAddToQuickView := AddButton(ToolBar, 'wishlist_add', 'Add selected item to Quick View List', AnyClick);
    btnShowItemInListPage := AddButton(ToolBar, 'table_select_row', 'Show item in its List Page', AnyClick);
    AddSeparator(ToolBar);
    btnExpandAll := AddButton(ToolBar, 'Tree_Expand', 'Expand All', AnyClick);
    btnCollapseAll := AddButton(ToolBar, 'Tree_Collapse', 'Collapse All', AnyClick);
  finally
    ToolBar.Parent := P;
  end;
end;

procedure TSearchForm.AnyClick(Sender: TObject);
begin
  if btnAddToQuickView = Sender then
    AddToQuickView()
  else if btnShowItemInListPage = Sender then
    ShowItemInListPage()
  else if btnExpandAll = Sender then
    ExpandAll()
  else if btnCollapseAll = Sender then
    CollapseAll();
end;

procedure TSearchForm.edtSearchOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
     GlobalSearchTermChanged();
end;

procedure TSearchForm.tv_OnDoubleClick(Sender: TObject);
begin
  ShowLinkItemPage();
end;

procedure TSearchForm.tv_OnSelectedNodeChanged(Sender: TObject; Node: TTreeNode);
begin
  SelectedNodeChanged();
end;

procedure TSearchForm.AddToQuickView();
var
  LinkItem: TLinkItem;
  LinkItem2: TLinkItem;
  TabPage : TTabSheet;
  frQuickView: TQuickViewForm;
begin
  if Assigned(tv.Selected) and Assigned(tv.Selected.Data) then
  begin
    LinkItem := TLinkItem(tv.Selected.Data);
    App.UpdateLinkItemUi(LinkItem, pnlTitle, frmText.TextEditor);
    Application.ProcessMessages();
  end;

  TabPage :=  App.SideBarPagerHandler.ShowPage(TQuickViewForm, TQuickViewForm.ClassName, nil);
  if (not Assigned(TabPage)) or (TabPage.Tag = 0) then
    Exit;

  LinkItem2 := TLinkItem.Create(nil);
  LinkItem2.Item := LinkItem.Item;
  LinkItem2.ItemType := LinkItem.ItemType;
  LinkItem2.Place := LinkItem.Place;
  LinkItem2.Title := LinkItem.Title;

  frQuickView := TQuickViewForm(TabPage.Tag);
  frQuickView.AddToQuickView(LinkItem2);
end;

procedure TSearchForm.ExpandAll();
begin
  tv.FullExpand();
end;

procedure TSearchForm.CollapseAll();
begin
  tv.FullCollapse();
end;

end.

