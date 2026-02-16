program StoryWriter;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, f_mainform, Tripous, o_entities, o_app, Tripous.IconList,
  Tripous.Forms.FramePage, Tripous.Forms.PagerHandler, o_AppSettings,
  fr_StoryList, fr_Scene, fr_TextEditor, f_FindAndReplaceDialog,
  o_SearchAndReplace, fr_MarkdownPreview, fr_CategoryList, fr_TagList,
  fr_ComponentList, fr_Search, u_ProjectGlobalSearch, fr_QuickView, fr_NoteList,
  fr_TempText;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

