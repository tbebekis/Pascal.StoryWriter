unit fr_StoryList;

{$MODE DELPHI}{$H+}

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
  , Contnrs
  , Menus
  , StdCtrls
  , Tripous.Broadcaster
  , fr_FramePage
  , o_Entities
  , fr_TextEditor
  ;

type

  { TfrStoryList }

  TfrStoryList = class(TFramePage)
    frText: TfrTextEditor;
    mmoTextMetrics: TMemo;
    mnuAddStory: TMenuItem;
    mnuAddChapter: TMenuItem;
    mnuAddScene: TMenuItem;
    mnuAddItem: TPopupMenu;
    Panel1: TPanel;
    pnlTitle: TPanel;
    tvImages: TImageList;
    pnlTop: TPanel;
    pnlBottom: TPanel;
    pnlTextMetrics: TPanel;
    Splitter: TSplitter;
    Splitter2: TSplitter;
    ToolBar: TToolBar;
    tv: TTreeView;
  private
    btnAddItem : TToolButton;
    btnEditItem : TToolButton;
    btnDeleteItem : TToolButton;
    btnEditText: TToolButton;
    btnExportStory: TToolButton;
    btnChangeParent: TToolButton;
    btnCollapseAll: TToolButton;
    btnExpandAll: TToolButton;
    btnUp: TToolButton;
    btnDown: TToolButton;

    // ● event handler
    procedure AnyClick(Sender: TObject);

    procedure tv_OnDblClick(Sender: TObject);
    procedure tv_OnMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure tv_OnSelectedNodeChanged(Sender: TObject; Node: TTreeNode);

    function NodeAsObject(Node: TTreeNode): TObject;
    function NodeAsStory(Node: TTreeNode): TStory;
    function NodeAsChapter(Node: TTreeNode): TChapter;
    function NodeAsScene(Node: TTreeNode): TScene;

    procedure PrepareToolBar();

    procedure ReLoad();
    procedure SelectedNodeChanged();

    procedure AddStory();
    procedure EditStory();
    procedure DeleteStory();

    procedure AddChapter();
    procedure EditChapter();
    procedure DeleteChapter();

    procedure AddScene();
    procedure EditScene();
    procedure DeleteScene();

    procedure EditItem();
    procedure DeleteItem();
    procedure EditItemText();

    procedure ExportStory();

    procedure MoveStory(Story: TStory; Node: TTreeNode; Up: Boolean);
    procedure MoveChapter(Chapter: TChapter; Node: TTreeNode; Up: Boolean);
    procedure MoveScene(Scene: TScene; Node: TTreeNode; Up: Boolean);
    procedure MoveNode(Up: Boolean);
    procedure UpdateNodeTitles(ParentNode: TTreeNode);

    procedure ChangeParent();
    procedure CollapseAll();
    procedure ExpandAll();

    procedure UpdateTextMetrics();

    function GetStoryNode: TTreeNode;
    function GetChapterNode: TTreeNode;
  protected
    procedure OnBroadcasterEvent(Args: TBroadcasterArgs); override;
  public
    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;

    function ShowItemInList(Item: TBaseItem): Boolean;
  end;

implementation

{$R *.lfm}

uses
   Tripous.Logs
  ,o_Consts
  ,o_App
  ,o_StoryExporter
  ,fr_Story
  ,fr_Chapter
  ,fr_Scene
  ,f_EditItemDialog
  ,f_SelectParentDialog
  ;



{ TfrStoryList }

procedure TfrStoryList.ControlInitialize;
begin
  inherited ControlInitialize;

  ParentTabPage.Caption := 'Stories';

  PrepareToolBar();

  frText.ToolBarVisible := False;
  frText.Editor.ReadOnly := True;

  tv.ReadOnly := True ;
  tv.OnDblClick := tv_OnDblClick;
  tv.OnMouseDown := tv_OnMouseDown;
  tv.OnChange := tv_OnSelectedNodeChanged;

  ReLoad();
end;

procedure TfrStoryList.ControlInitializeAfter();
begin
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
  tv.Width :=  (pnlTop.ClientWidth - Splitter2.Width) div 2;
end;

function TfrStoryList.ShowItemInList(Item: TBaseItem): Boolean;
  // -------------------------------------------
  function SetSelectedNode(Nodes: TTreeNodes): Boolean;
  var
    i : Integer;
    Node: TTreeNode;
  begin
    Result := False;

    for i := 0 to Nodes.Count - 1 do
    begin
      Node := Nodes[i];
      if Assigned(Node.Data) and (TObject(Node.Data) = Item) then
      begin
        tv.Selected := Node;
        Exit(True);
      end;

      if SetSelectedNode(Node.TreeNodes) then
        Exit(True);
    end;
  end;
  // -------------------------------------------
begin
  Result := SetSelectedNode(tv.Items);
end;

procedure TfrStoryList.AnyClick(Sender: TObject);
begin
  if mnuAddStory = Sender then
    AddStory()
  else if mnuAddChapter = Sender then
    AddChapter()
  else if mnuAddScene = Sender then
    AddScene()
  else if btnEditItem = Sender then
    EditItem()
  else if btnDeleteItem = Sender then
    DeleteItem()
  else if btnEditText = Sender then
    EditItemText()
  else if btnExportStory = Sender then
    ExportStory()
  else if btnChangeParent = Sender then
    ChangeParent()
  else if btnExpandAll = Sender then
    ExpandAll()
  else if btnCollapseAll = Sender then
    CollapseAll()
  else if btnUp = Sender then
    MoveNode(True)
  else if btnDown = Sender then
    MoveNode(False)
end;

procedure TfrStoryList.tv_OnDblClick(Sender: TObject);
begin
  EditItem();
end;

procedure TfrStoryList.tv_OnMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Node: TTreeNode;
begin
  if Button <> mbRight then Exit;

  Node := tv.GetNodeAt(X, Y);
  if not Assigned(Node) then Exit;

  tv.Selected := Node;
  EditItemText();
end;

procedure TfrStoryList.tv_OnSelectedNodeChanged(Sender: TObject; Node: TTreeNode);
begin
  SelectedNodeChanged();
end;

procedure TfrStoryList.PrepareToolBar();
var
  P: TWinControl;
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  P := ToolBar.Parent;
  ToolBar.Parent := nil;
  try
    btnAddItem := AddButton(ToolBar, 'table_add', 'Add Chapter or Scene', nil);
    btnAddItem.Style := tbsDropDown;
    btnAddItem.DropdownMenu := mnuAddItem;
    mnuAddStory.OnClick := AnyClick;
    mnuAddChapter.OnClick := AnyClick;
    mnuAddScene.OnClick := AnyClick;
    btnEditItem := AddButton(ToolBar, 'table_edit', 'Edit', AnyClick);
    btnDeleteItem := AddButton(ToolBar, 'table_delete', 'Remove', AnyClick);
    AddSeparator(ToolBar);
    btnEditText := AddButton(ToolBar, 'page_edit', 'Edit Text', AnyClick);
    btnExportStory := AddButton(ToolBar, 'table_export', 'Export Story', AnyClick);
    btnChangeParent := AddButton(ToolBar, 'scroll_pane_tree', 'Change Parent', AnyClick);
    btnCollapseAll := AddButton(ToolBar, 'Tree_Collapse', 'Collapse All', AnyClick);
    btnExpandAll := AddButton(ToolBar, 'Tree_Expand', 'Expand All', AnyClick);
    btnUp := AddButton(ToolBar, 'arrow_up', 'Move Up', AnyClick);
    btnDown := AddButton(ToolBar, 'arrow_down', 'Move Down', AnyClick);
  finally
    ToolBar.Parent := P;
  end;
end;

procedure TfrStoryList.ReLoad;
var
  i, j, k: Integer;
  StoryNode: TTreeNode;
  ChapterNode: TTreeNode;
  SceneNode: TTreeNode;
  Story: TStory;
  Chapter: TChapter;
  Scene: TScene;
begin
  tv.BeginUpdate;
  try
    tv.Items.Clear;

    if App.CurrentProject = nil then
      Exit;

    for i := 0 to App.CurrentProject.StoryList.Count - 1 do
    begin
      Story := TStory(App.CurrentProject.StoryList.Items[i]);

      StoryNode := tv.Items.Add(nil, Story.DisplayTitle);
      StoryNode.Data := Story;
      StoryNode.ImageIndex := 0;
      StoryNode.SelectedIndex := 0;

      for j := 0 to Story.ChapterList.Count - 1 do
      begin
        Chapter := TChapter(Story.ChapterList.Items[j]);

        ChapterNode := tv.Items.AddChild(StoryNode, Chapter.DisplayTitle);
        ChapterNode.Data := Chapter;
        ChapterNode.ImageIndex := 1;
        ChapterNode.SelectedIndex := 1;

        for k := 0 to Chapter.SceneList.Count - 1 do
        begin
          Scene := TScene(Chapter.SceneList.Items[k]);

          SceneNode := tv.Items.AddChild(ChapterNode, Scene.DisplayTitle);
          SceneNode.Data := Scene;
          SceneNode.ImageIndex := 2;
          SceneNode.SelectedIndex := 2;
        end;
      end;
    end;

  finally
    tv.EndUpdate;
  end;

  SelectedNodeChanged;
end;

procedure TfrStoryList.SelectedNodeChanged();
var
  Node: TTreeNode;
  Item: TObject;
  Story: TStory;
  Chapter: TChapter;
  Scene: TScene;
begin
  pnlTitle.Caption := 'No selection';
  frText.Editor.Clear();

  if not Assigned(App.CurrentProject) then
    Exit;

  Node := tv.Selected;
  if (not Assigned(Node)) or (not Assigned(Node.Data)) then
    Exit;

  Item := TObject(Node.Data);

  if Item is TStory then
  begin
    Story := Item as TStory;
    pnlTitle.Caption := Format('Story: %s', [Story.Title]);
    frText.EditorText := Story.Synopsis;
  end else if Item is TChapter then
  begin
    Chapter := Item as TChapter;
    pnlTitle.Caption := Format('Chapter: %s', [Chapter.Title]);
    frText.EditorText := Chapter.Synopsis;
  end else if Item is TScene then
  begin
    Scene := Item as TScene;
    pnlTitle.Caption := Format('Scene: %s', [Scene.Title]);
    frText.EditorText := Scene.Text;
  end;

end;

procedure TfrStoryList.EditItem();
var
  Node: TTreeNode;
  Item: TObject;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Node := tv.Selected;
  if (not Assigned(Node)) or (not Assigned(Node.Data)) then
    Exit;

  Item := TObject(Node.Data);

  if Item is TStory then
  begin
    EditStory();
  end else if Item is TChapter then
  begin
    EditChapter();
  end else if Item is TScene then
  begin
    EditScene();
  end;

end;

procedure TfrStoryList.DeleteItem();
var
  Node: TTreeNode;
  Item: TObject;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Node := tv.Selected;
  if (not Assigned(Node)) or (not Assigned(Node.Data)) then
    Exit;

  Item := TObject(Node.Data);

  if Item is TStory then
  begin
    DeleteStory();
  end else if Item is TChapter then
  begin
    DeleteChapter();
  end else if Item is TScene then
  begin
    DeleteScene();
  end;
end;

procedure TfrStoryList.EditItemText();
var
  Node: TTreeNode;
  Item: TBaseItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Node := tv.Selected;
  if (not Assigned(Node)) or (not Assigned(Node.Data)) then
    Exit;

  Item := TBaseItem(Node.Data);

  if Item is TStory then
  begin
    App.ContentPagerHandler.ShowPage(TfrStory, Item.Id, Item)
  end else if Item is TChapter then
  begin
    App.ContentPagerHandler.ShowPage(TfrChapter, Item.Id, Item)
  end else if Item is TScene then
  begin
    App.ContentPagerHandler.ShowPage(TfrScene, Item.Id, Item);
  end;

end;

procedure TfrStoryList.AddStory();
var
  Message: string;
  ResultName: string;
  Count: Integer;
  Node: TTreeNode;
  Story: TStory;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  ResultName := '';

  if TEditItemDialog.ShowDialog('Add Story', App.CurrentProject.Title, ResultName) then
  begin
    Count := App.CurrentProject.CountStoryTitle(ResultName);
    if Count > 0 then
    begin
      Message := Format('Story already exists: %s', [ResultName]);
      App.ErrorBox(Message);
      LogBox.AppendLine(Message);
      Exit;
    end;

    Story := App.CurrentProject.AddStory(ResultName);
    Node :=  tv.Items.Add(nil, Story.DisplayTitle);
    Node.Data := Story;
    Node.ImageIndex := 0;
    Node.SelectedIndex := 0;

    Message := Format('Story added: %s', [ResultName]);
    LogBox.AppendLine(Message);

    tv.Selected := Node;
  end;
end;

procedure TfrStoryList.EditStory();
var
  Message: string;
  ResultName: string;
  Count: Integer;
  Node: TTreeNode;
  Story: TStory;
  TabPage: TTabSheet;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Node := tv.Selected;
  if (not Assigned(Node)) or (not Assigned(Node.Data)) then
    Exit;

  Story := TStory(Node.Data);

  ResultName := Story.Title;
  if TEditItemDialog.ShowDialog('Edit Story', App.CurrentProject.Title, ResultName) then
  begin
    Count := App.CurrentProject.CountStoryTitle(ResultName);
    if Count > 1 then
    begin
      Message := Format('Story already exists: %s', [ResultName]);
      App.ErrorBox(Message);
      LogBox.AppendLine(Message);
      Exit;
    end;

    Story.Title := ResultName;
    Node.Text := Story.DisplayTitle;

    TabPage := App.ContentPagerHandler.FindTabPage(Story.Id);
    if Assigned(TabPage) and (TabPage.Tag > 0) then
      TfrStory(TabPage.Tag).TitleChanged();

    Message := Format('Story updated: %s', [ResultName]);
    LogBox.AppendLine(Message);
  end;

end;

procedure TfrStoryList.DeleteStory();
var
  Message: string;
  Node: TTreeNode;
  Story: TStory;
  Item: TCollectionItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Node := tv.Selected;
  if (not Assigned(Node)) or (not Assigned(Node.Data)) then
    Exit;

  Story := TStory(Node.Data);
  Message :=
    'Deleting a Story deletes all of its Chapters too.' + LineEnding +
    'Are you sure you want to delete the Story' + LineEnding +
    '''' + Story.Title + '''?';

  if not App.QuestionBox(Message) then
    Exit;

  tv.Items.Delete(Node);

  for Item in Story.ChapterList do
    App.ContentPagerHandler.ClosePage(TBaseItem(Item).Id);

  App.ContentPagerHandler.ClosePage(Story.Id);

  Story.Delete();
end;

procedure TfrStoryList.AddChapter();
var
  Node: TTreeNode;
  Story: TStory;
  Chapter: TChapter;
  StoryNode: TTreeNode;
  Count: Integer;
  Message: string;
  ResultName: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  StoryNode := GetStoryNode();
  if not Assigned(StoryNode) then
  begin
    Message := 'Please, select a Story first.';
    App.ErrorBox(Message);
    LogBox.AppendLine(Message);
    Exit;
  end;

  Story := TStory(StoryNode.Data);
  ResultName := '';

  if TEditItemDialog.ShowDialog('Add Chapter', App.CurrentProject.Title, ResultName) then
  begin
    Count := Story.CountChapterTitle(ResultName);
    if (Count > 0) then
    begin
      Message := Format('Chapter already exists: %s', [ResultName]);
      App.ErrorBox(Message);
      LogBox.AppendLine(Message);
      Exit;
    end;

    Chapter := Story.AddChapter(ResultName);
    Node := tv.Items.AddChild(StoryNode, Chapter.DisplayTitle);
    Node.Data := Chapter;
    Node.ImageIndex := 1;
    Node.SelectedIndex := 1;

    Message := Format('Chapter added: %s', [ResultName]);
    LogBox.AppendLine(Message);

    tv.Selected := Node;
  end;

end;

procedure TfrStoryList.EditChapter();
var
  Message: string;
  ResultName: string;
  Count: Integer;
  Node: TTreeNode;
  Chapter: TChapter;
  TabPage: TTabSheet;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Node := tv.Selected;
  if (not Assigned(Node)) or (not Assigned(Node.Data)) then
    Exit;

  Chapter := TChapter(Node.Data);

  ResultName := Chapter.Title;
  if TEditItemDialog.ShowDialog('Edit Chapter', App.CurrentProject.Title, ResultName) then
  begin
    Count := Chapter.Story.CountChapterTitle(ResultName);
    if Count > 1 then
    begin
      Message := Format('Chapter already exists: %s', [ResultName]);
      App.ErrorBox(Message);
      LogBox.AppendLine(Message);
      Exit;
    end;

    Chapter.Title := ResultName;
    Node.Text := Chapter.DisplayTitle;

    TabPage := App.ContentPagerHandler.FindTabPage(Chapter.Id);
    if Assigned(TabPage) and (TabPage.Tag > 0) then
      TfrChapter(TabPage.Tag).TitleChanged();

    Message := Format('Chapter updated: %s', [ResultName]);
    LogBox.AppendLine(Message);
  end;
end;

procedure TfrStoryList.DeleteChapter();
var
  Message: string;
  Node: TTreeNode;
  Chapter: TChapter;
  Item: TCollectionItem;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Node := tv.Selected;
  if (not Assigned(Node)) or (not Assigned(Node.Data)) then
    Exit;

  Chapter := TChapter(Node.Data);
  Message :=
    'Deleting a Chapter deletes all of its Scenes too.' + LineEnding +
    'Are you sure you want to delete the Chapter' + LineEnding +
    '''' + Chapter.Title + '''?';

  if not App.QuestionBox(Message) then
    Exit;

  tv.Items.Delete(Node);

  for Item in Chapter.SceneList do
    App.ContentPagerHandler.ClosePage(TBaseItem(Item).Id);

  App.ContentPagerHandler.ClosePage(Chapter.Id);

  Chapter.Delete();

end;

procedure TfrStoryList.AddScene();
var
  Node: TTreeNode;
  Chapter: TChapter;
  Scene: TScene;
  ChapterNode: TTreeNode;
  Count: Integer;
  Message: string;
  ResultName: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  ChapterNode := GetChapterNode();
  if not Assigned(ChapterNode) then
  begin
    Message := 'Please, select a Chapter first.';
    App.ErrorBox(Message);
    LogBox.AppendLine(Message);
    Exit;
  end;

  Chapter := TChapter(ChapterNode.Data);
  ResultName := '';

  if TEditItemDialog.ShowDialog('Add Scene', App.CurrentProject.Title, ResultName) then
  begin
    Count := Chapter.CountSceneTitle(ResultName);
    if (Count > 0) then
    begin
      Message := Format('Scene already exists: %s', [ResultName]);
      App.ErrorBox(Message);
      LogBox.AppendLine(Message);
      Exit;
    end;

    Scene := Chapter.AddScene(ResultName);
    Node := tv.Items.AddChild(ChapterNode, Scene.DisplayTitle);
    Node.Data := Scene;
    Node.ImageIndex := 2;
    Node.SelectedIndex := 2;

    Message := Format('Scene added: %s', [ResultName]);
    LogBox.AppendLine(Message);

    tv.Selected := Node;
  end;
end;

procedure TfrStoryList.EditScene();
var
  Message: string;
  ResultName: string;
  Count: Integer;
  Node: TTreeNode;
  Scene: TScene;
  TabPage: TTabSheet;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Node := tv.Selected;
  if (not Assigned(Node)) or (not Assigned(Node.Data)) then
    Exit;

  Scene := TScene(Node.Data);

  ResultName := Scene.Title;
  if TEditItemDialog.ShowDialog('Edit Scene', App.CurrentProject.Title, ResultName) then
  begin
    Count := Scene.Chapter.CountSceneTitle(ResultName);
    if Count > 1 then
    begin
      Message := Format('Scene already exists: %s', [ResultName]);
      App.ErrorBox(Message);
      LogBox.AppendLine(Message);
      Exit;
    end;

    Scene.Title := ResultName;
    Node.Text := Scene.DisplayTitle;

    TabPage := App.ContentPagerHandler.FindTabPage(Scene.Id);
    if Assigned(TabPage) and (TabPage.Tag > 0) then
      TfrScene(TabPage.Tag).TitleChanged();

    Message := Format('Scene updated: %s', [ResultName]);
    LogBox.AppendLine(Message);
  end;

end;

procedure TfrStoryList.DeleteScene();
var
  Message: string;
  Node: TTreeNode;
  Scene: TScene;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Node := tv.Selected;
  if (not Assigned(Node)) or (not Assigned(Node.Data)) then
    Exit;

  Scene := TScene(Node.Data);
  Message :=
    'Are you sure you want to delete the Scene' + LineEnding +
    '''' + Scene.Title + '''?';

  if not App.QuestionBox(Message) then
    Exit;

  tv.Items.Delete(Node);

  App.ContentPagerHandler.ClosePage(Scene.Id);

  Scene.Delete();

end;

procedure TfrStoryList.ExportStory();
var
  Message: string;
  StoryNode: TTreeNode;
  Story: TStory;
begin

  if not Assigned(App.CurrentProject) then
    Exit;

  StoryNode := GetStoryNode();
  if not Assigned(StoryNode) then
  begin
    Message := 'Please, select a Story first.';
    LogBox.AppendLine(Message);
    App.ErrorBox(Message);
    Exit;
  end;

  Story := TStory(StoryNode.Data);
  TStoryExporter.Export(Story);
end;

procedure TfrStoryList.MoveStory(Story: TStory; Node: TTreeNode; Up: Boolean);
var
  Index: Integer;
begin
  if (Story = nil) or (Node = nil) then
    Exit;

  Index := Node.Index;       // index among top-level nodes
  //Count := tv.Items.Count;   // includes children too, so DO NOT use this for bounds

  // bounds check using siblings:
  if Up then
    if Index = 0 then Exit
  else if Node.GetNextSibling = nil
    then Exit;

  if Story.CanMove(Up) then
  begin
    Story.Move(Up);

    tv.Items.BeginUpdate;
    try
      Node.MoveTo(nil, naAdd);                         // detach safety; optional
      Node.MoveTo(tv.Items.GetFirstNode, naInsert);    // placeholder; we'll use MoveTo with sibling below
      // Better: move relative to siblings by OrderIndex:
      // We'll locate target sibling at AStory.OrderIndex and insert before it.
      // But easiest is: delete+insert using Items.Insert + manual copy isn't worth it.
    finally
      tv.Items.EndUpdate;
    end;

    // Practical approach: use Index-based MoveTo.
    // MoveTo supports: naInsert (before a sibling) or naAddChild etc.
    // We'll move node before/after sibling based on Up.
    if Up then
      Node.MoveTo(Node.GetPrevSibling, naInsert)
    else
      Node.MoveTo(Node.GetNextSibling, naInsertBehind);

    UpdateNodeTitles(nil);
  end;

end;

procedure TfrStoryList.MoveChapter(Chapter: TChapter; Node: TTreeNode; Up: Boolean);
var
  ParentNode: TTreeNode;
begin
  if (Chapter = nil) or (Node = nil) then
    Exit;

  ParentNode := Node.Parent;
  if ParentNode = nil then
    Exit;

  if Up then
  begin
    if Node.GetPrevSibling = nil then Exit;
  end
  else
  begin
    if Node.GetNextSibling = nil then Exit;
  end;

  if Chapter.CanMove(Up) then
  begin
    Chapter.Move(Up);

    if Up then
      Node.MoveTo(Node.GetPrevSibling, naInsert)
    else
      Node.MoveTo(Node.GetNextSibling, naInsertBehind);

    UpdateNodeTitles(ParentNode);
  end;

end;

procedure TfrStoryList.MoveScene(Scene: TScene; Node: TTreeNode; Up: Boolean);
var
  ParentNode: TTreeNode;
begin
  if (Scene = nil) or (Node = nil) then
    Exit;

  ParentNode := Node.Parent;
  if ParentNode = nil then
    Exit;

  if Up then
  begin
    if Node.GetPrevSibling = nil then Exit;
  end
  else
  begin
    if Node.GetNextSibling = nil then Exit;
  end;

  if Scene.CanMove(Up) then
  begin
    Scene.Move(Up);

    if Up then
      Node.MoveTo(Node.GetPrevSibling, naInsert)
    else
      Node.MoveTo(Node.GetNextSibling, naInsertBehind);

    UpdateNodeTitles(ParentNode);
  end;

end;

procedure TfrStoryList.MoveNode(Up: Boolean);
var
  Node: TTreeNode;
  Obj: TObject;
begin
  Node := tv.Selected;
  if Node = nil then
    Exit;

  Obj := TObject(Node.Data);

  if Obj is TStory then
    MoveStory(TStory(Obj), Node, Up)
  else if Obj is TChapter then
    MoveChapter(TChapter(Obj), Node, Up)
  else if Obj is TScene then
    MoveScene(TScene(Obj), Node, Up);

  tv.Selected := Node;

end;

procedure TfrStoryList.UpdateNodeTitles(ParentNode: TTreeNode);
var
  N: TTreeNode;
  Item: TBaseItem;
begin
  if ParentNode <> nil then
    N := ParentNode.GetFirstChild
  else
    N := tv.Items.GetFirstNode; // top-level

  while N <> nil do
  begin
    Item := TBaseItem(N.Data);
    if Item <> nil then
      N.Text := Item.DisplayTitle;

    if ParentNode <> nil then
      N := N.GetNextSibling
    else
      N := N.GetNextSibling; // only top-level siblings (stories)
  end;

end;

procedure TfrStoryList.ChangeParent;
  // --------------------------------------------------------------
  function FindNodeByData(ANodes: TTreeNodes; AData: Pointer): TTreeNode;
  var
    N: TTreeNode;
  begin
    Result := nil;
    N := ANodes.GetFirstNode;
    while N <> nil do
    begin
      if N.Data = AData then
        Exit(N);

      if N.HasChildren then
      begin
        Result := FindNodeByData(N.Owner, AData); // fallback, but better recurse via child list (see below)
      end;

      N := N.GetNext;
    end;
  end;
  // --------------------------------------------------------------
  function FindNodeByDataRec(ANode: TTreeNode; AData: Pointer): TTreeNode;
  var
    C: TTreeNode;
  begin
    Result := nil;
    if (ANode <> nil) and (ANode.Data = AData) then
      Exit(ANode);

    if ANode = nil then
      Exit(nil);

    C := ANode.GetFirstChild;
    while C <> nil do
    begin
      Result := FindNodeByDataRec(C, AData);
      if Result <> nil then
        Exit;
      C := C.GetNextSibling;
    end;
  end;
  // --------------------------------------------------------------
  function FindNodeInTree(ATree: TCustomTreeView; AData: Pointer): TTreeNode;
  var
    N: TTreeNode;
  begin
    Result := nil;
    N := ATree.Items.GetFirstNode;
    while N <> nil do
    begin
      Result := FindNodeByDataRec(N, AData);
      if Result <> nil then
        Exit;
      N := N.GetNextSibling;
    end;
  end;
  // --------------------------------------------------------------
  function GetParentsExcept(Chapter: TChapter): TObjectList; overload;
  var
    Item: TCollectionItem;
  begin
    Result := TObjectList.Create(False);
    for Item in Chapter.Story.Project.StoryList do
    begin
      if Item <> Chapter.Story then
        Result.Add(Item);
    end;
  end;
  // --------------------------------------------------------------
  function GetParentsExcept(Scene: TScene): TObjectList; overload;
  var
    Item: TCollectionItem;
  begin
    Result := TObjectList.Create(False);
    for Item in Scene.Chapter.Story.ChapterList do
    begin
      if Item <> Scene.Chapter then
        Result.Add(Item);
    end;
  end;
  // --------------------------------------------------------------
var
  Node, ParentNode: TTreeNode;
  ParentItem: TBaseItem;
  Chapter: TChapter;
  Scene: TScene;
  NewStory: TStory;
  NewChapter: TChapter;

  StoryList: TObjectList;   // non-owned list of items (or your list type)
  ChapterList: TObjectList; // non-owned list of items
begin
  Node := tv.Selected;
  if Node = nil then
    Exit;

  ParentItem := nil;

  // --- CHAPTER: change parent story -----------------------------------------
  if TObject(Node.Data) is TChapter then
  begin
    Chapter := TChapter(Node.Data);

    // build list of candidate stories except current
    StoryList := GetParentsExcept(Chapter);
    try

      if StoryList.Count = 0 then
        Exit;

      if TSelectParentDialog.ShowDialog(Chapter, StoryList, ParentItem) then
      begin
        NewStory := TStory(ParentItem);
        Chapter.ChangeParent(NewStory);

        ReLoad;

        ParentNode := FindNodeInTree(tv, Pointer(NewStory));
        if ParentNode <> nil then
        begin
          if ParentNode.Parent <> nil then
            ParentNode.Parent.Expand(True)
          else
            ParentNode.Expand(True);

          tv.Selected := FindNodeInTree(tv, Pointer(Chapter));
        end;
      end;
    finally
      StoryList.Free;
    end;
  end
  // --- SCENE: change parent chapter -----------------------------------------
  else if TObject(Node.Data) is TScene then
  begin
    Scene := TScene(Node.Data);

    ChapterList := GetParentsExcept(Scene);
    try
      if ChapterList.Count = 0 then
        Exit;

      if TSelectParentDialog.ShowDialog(Scene, ChapterList, ParentItem) then
      begin
        NewChapter := TChapter(ParentItem);
        Scene.ChangeParent(NewChapter);

        ReLoad;

        ParentNode := FindNodeInTree(tv, Pointer(NewChapter));
        if ParentNode <> nil then
        begin
          if ParentNode.Parent <> nil then
            ParentNode.Parent.Expand(True)
          else
            ParentNode.Expand(True);

          tv.Selected := FindNodeInTree(tv, Pointer(Scene));
        end;
      end;
    finally
      ChapterList.Free;
    end;
  end;
end;

procedure TfrStoryList.CollapseAll();
begin
  tv.BeginUpdate();
  try
    tv.FullCollapse();
  finally
    tv.EndUpdate();
  end;
end;

procedure TfrStoryList.ExpandAll();
begin
  tv.BeginUpdate();
  try
    tv.FullExpand();
  finally
    tv.EndUpdate();
  end;
end;

procedure TfrStoryList.UpdateTextMetrics();
var
  List: TStringList;
  Item: TCollectionItem;
  Story: TStory;
begin
  mmoTextMetrics.Clear();

  if not Assigned(App.CurrentProject) then
    Exit;

  List := TStringList.Create;
  try

    for Item in App.CurrentProject.StoryList do
    begin
      Story := TStory(Item);
      if Story.Index > 0 then
        List.Add('=========================');
      List.Add(Story.DisplayTitle);
      List.Add('-------------------------');
      List.Add(Format('Words: %d', [Story.Stats.WordCount]));
      List.Add(Format('Pages: %.2f', [Story.Stats.EstimatedPages]));
      List.Add(' ');
      List.Add(Format('Words En: %d', [Story.StatsEn.WordCount]));
      List.Add(Format('Pages En: %.2f', [Story.StatsEn.EstimatedPages]));
    end;

    List.Add('=========================');
    List.Add(Format('Components: %d', [App.CurrentProject.ComponentList.Count]));

    mmoTextMetrics.Text := List.Text;

  finally
    List.Free();
  end;

end;

procedure TfrStoryList.OnBroadcasterEvent(Args: TBroadcasterArgs);
var
  EventKind : TAppEventKind;
begin
  EventKind := AppEventKindOf(Args.Name);
  case EventKind of
    aekProjectOpened :
    begin
      ReLoad();
      SelectedNodeChanged();
    end;
    aekProjectClosed :
    begin
      tv.Items.Clear();
      SelectedNodeChanged();
    end;
    aekProjectMetricsChanged:
    begin
      UpdateTextMetrics();
    end;
  end;
end;

function TfrStoryList.NodeAsObject(Node: TTreeNode): TObject;
begin
  if Assigned(Node) and Assigned(Node.Data) then
    Result := TObject(Node.Data)
  else
    Result := nil;
end;

function TfrStoryList.NodeAsStory(Node: TTreeNode): TStory;
var
  Obj: TObject;
begin
  Result := nil;
  Obj := NodeAsObject(Node);
  if Obj is TStory then
    Result := TStory(Obj);
end;

function TfrStoryList.NodeAsChapter(Node: TTreeNode): TChapter;
var
  Obj: TObject;
begin
  Result := nil;
  Obj := NodeAsObject(Node);
  if Obj is TChapter then
    Result := TChapter(Obj);
end;

function TfrStoryList.NodeAsScene(Node: TTreeNode): TScene;
var
  Obj: TObject;
begin
  Result := nil;
  try
    Obj := NodeAsObject(Node);
    if Obj is TScene then
      Result := TScene(Obj);
  except
  end;
end;

function TfrStoryList.GetStoryNode: TTreeNode;
var
  Item: TBaseItem;
begin
  Result := nil;

  if Assigned(App.CurrentProject) and Assigned(tv.Selected) and Assigned(tv.Selected.Data)  then
  begin
    Item := TBaseItem(tv.Selected.Data);

    if Item is TStory then
      Result := tv.Selected
    else if Item is TChapter then
      Result := tv.Selected.Parent
    else if Item is TScene then;
      Result := tv.Selected.Parent.Parent;
  end;
end;

function TfrStoryList.GetChapterNode: TTreeNode;
var
  Item: TBaseItem;
begin
  Result := nil;

  if Assigned(App.CurrentProject) and Assigned(tv.Selected) and Assigned(tv.Selected.Data)  then
  begin
    Item := TBaseItem(tv.Selected.Data);

    if Item is TChapter then
      Result := tv.Selected
    else if Item is TScene then;
      Result := tv.Selected.Parent;
  end;
end;

end.

