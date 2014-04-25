unit YaDsk;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Data.Win.ADODB,idHttp,idSSl,
  IdSSLOpenSSL,IdIOHandler,RegularExpressionsAPI,RegularExpressionsCore,
  RegularExpressionsConsts,RegularExpressions,idGlobalProtocols,idGlobal,
  vcl.dialogs;


type
  TWebDav = class(TIdHTTP)
  public
    procedure MkCol(AURL: string);
    procedure Copy(AURL:String);
    procedure Move(AURL:String);
    function Prop(HttpMethod:String;AURL:String;ASource:TStrings):String;
end;

type
  TYaDsk = class(TWebDav)
  private
    Http:       TWebDav;
    Ssl:        TIdSSLIOHandlerSocketOpenSSL;
    function    RegEx(Str:String;Expression:string):string;
  public
    constructor Create(Login:String;Password:String);
    destructor  Destroy;
    procedure   Put(FileName:String);
    procedure   Get(FileName:String);
    procedure   Delete(ObjectName:String);
    procedure   MkCol(AURL: string);
    procedure   Copy(inPath,outPath:String);
    procedure   Folder(FolderName:String;Depth:integer);
    procedure   Move(inPath,outPath:String);
    procedure   GetSpaceDisk(var Available: String; var Used: String);
    procedure   GetProperties(ObjectName:String);
    function    Share(FileName:String;Open:Boolean = true):String;
    function    IsShare(FileName:String): boolean;
    function    GetLogin():String;
  end;

const

USERAGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:25.0) Gecko/20100101 Firefox/25.0';
YaURL = 'https://webdav.yandex.ru/';
ApplicationName = 'YaDisk DelphiSDK/0.0.1';
Id_HTTPMethodMkCol = 'MKCOL';
Id_HTTPMethodCopy = 'COPY';
Id_HTTPMethodMove = 'MOVE';
Id_HTTPMethodPropPatch = 'PROPPATCH';
Id_HTTPMethodPropFind = 'PROPFIND';


procedure Register;

implementation

{$REGION 'TWebDav'}
function TYaDsk.RegEx(Str:String;Expression: String):String;
var
  Reg:TRegEx;
begin
  Reg:=TRegex.Create(Expression);
  if Reg.IsMatch(Str) then
    Result:=Reg.Match(Str).Value;
end;

procedure TWebDav.MkCol(AURL: string);
begin
  DoRequest(Id_HTTPMethodMkCol, AURL, nil, nil, []);
end;

procedure TWebdav.Copy(AURL: string);
begin
  DoRequest(Id_HTTPMethodCopy, AURL, nil, nil, []);
end;

procedure TWebdav.Move(AURL: string);
begin
  DoRequest(Id_HTTPMethodMove, AURL, nil, nil, []);
end;

function TWebdav.Prop(HttpMethod:String;AURL: string;  ASource:TStrings):string;
var
  LResponse, Source: TMemoryStream;
begin
  try
    LResponse := TMemoryStream.Create;
    Source := TMemoryStream.Create;
    if ASource<>nil then
      Asource.SaveToStream(Source);
    DoRequest(HttpMethod, AURL, Source, LResponse, []);
    SetString(Result,PAnsiChar(LResponse.memory),LResponse.Size);
  finally
    FreeAndNil(LResponse);
    FreeAndNil(Source);
  end;
end;

{$ENDREGION}

{$REGION 'TYaDisk'}

constructor TYaDsk.Create(Login:String;Password:String);
begin
  http:=TWebDav.Create;
  ssl:=TIdSSLIOHandlerSocketOpenSSL.Create;
  with SSL.SSLOptions do
  begin
    Method:=sslvSSLv3;
    Mode:=sslmUnassigned;
    VerifyMode:=[];
    VerifyDepth:=0;
  end;

  ssl.Host:=String.Empty;
  http.IOHandler:=ssl;

  with http.Request do
  begin
    UserAgent:=USERAGENT;
    BasicAuthentication:=true;
    Username:=Login;
    Password:=Password;
  end;
end;

destructor TYaDsk.Destroy;
begin
  FreeAndNil(http);
  FreeAndNil(ssl);
end;

function TYaDsk.GetLogin:String;
begin
  with http.Request do
  begin
    UserAgent:=USERAGENT;
    Accept:='*/*';
  end;
  Result:=http.Get(YaURL+'?userinfo');
end;

procedure TYaDsk.Put(FileName: string);
var
Stream:TFileStream;
begin
  Stream:=TFileStream.Create(Filename,fmOpenRead);
  with http.Request do
  begin
    CustomHeaders.AddValue('Expect','100-continue');
    ContentType:='application/binary';
    ContentLength:=stream.Size;
  end;
  http.put(YaURL+Filename,stream);
  Stream.Free;
end;

procedure TYaDsk.Get(FileName: string);
var
  Stream:TStream;
begin
  Stream:=TFileStream.Create(Filename,fmcreate);
  http.get(YaURL+Filename,stream);
  stream.Free;
end;


procedure TYaDsk.MkCol(AURL: string);
begin
  http.Request.Accept:='*/*';
  http.MkCol(YaURL+Aurl);
end;

procedure TYaDsk.Delete(ObjectName: string);
begin
  http.Delete(YaURL+ObjectName);
end;

procedure TYaDsk.Copy(inPath: string; outPath: string);
begin
 with http.Request do
  begin
    Accept:='*/*';
    CustomHeaders.AddValue('Destination','/'+inPath);
  end;
  http.Copy(YaURL+outPath);
end;

procedure TYaDsk.Move(inPath: string; outPath: string);
begin
 with http.Request do
  begin
    Accept:='*/*';
    CustomHeaders.AddValue('Destination','/'+inPath);
  end;
  http.Move(YaURL+outPath);
end;

procedure TYaDsk.GetSpaceDisk(var Available: String; var Used: String);
var
  Answer:String;
  Stream:TStringList;
 begin
  Stream:=TStringList.Create;
  Stream.Add('<D:propfind xmlns:D="DAV:">');
  Stream.Add('  <D:prop>');
  Stream.Add('    <D:quota-available-bytes/>');
  Stream.Add('    <D:quota-used-bytes/>');
  Stream.Add('  </D:prop>');
  Stream.Add('</D:propfind>');
  with http.Request do
    begin
      Accept:=  '*/*';
      CustomHeaders.AddValue('Depth','0');
    end;
  Answer:=http.Prop(Id_HTTPMethodPropFind,YaURL,Stream);
  Available:= Regex(Answer,'<d:quota-available-bytes>(.*?)</d:quota-available-bytes>');
  Used := Regex(Answer,'<d:quota-used-bytes>(.*?)</d:quota-used-bytes>');
  FreeAndNil(Stream);
end;

procedure TYaDsk.Folder(FolderName: string;Depth:integer);
var
  Answer:AnsiString;
 begin
  with http.Request do
    begin
      Accept:=  '*/*';
      CustomHeaders.AddValue('Depth',IntToStr(Depth));
    end;
  Answer:=http.Prop(Id_HTTPMethodPropFind,YaURL,nil);
  showmessage(answer);
end;

procedure TYadsk.GetProperties(ObjectName: string);
var
  Answer:String;
  Stream:TStringList;
 begin
  Stream:=TStringList.Create;
  Stream.Add('<?xml version="1.0" encoding="utf-8" ?>');
  Stream.Add('<propfind xmlns="DAV:">');
  Stream.Add('<prop>');
  Stream.Add('<myprop xmlns="mynamespace"/>');
  Stream.Add('</prop>');
  Stream.Add('</propfind>');
  with http.Request do
    begin
      Accept              := '*/*';
      CustomHeaders.AddValue('Depth','1');
      ContentLength       :=Length(stream.GetText);
      ContentType         :='application/x-www-form-urlencoded';
    end;
  Answer:=http.Prop(Id_HTTPMethodPropFind,YaURL+ObjectName,Stream);
  showmessage(answer);
  //Regex(Answer,'<public_url xmlns="urn:yandex:disk:meta">(.*?)</public_url>');
  FreeAndNil(Stream);
end;

function TYaDsk.Share(FileName: string; Open: Boolean = True):String;
var
  Answer:String;
  Stream:TStringList;
 begin
  Stream:=TStringList.Create;
  Stream.Add('<propertyupdate xmlns="DAV:">');
  Stream.Add('<set>');
  Stream.Add('<prop>');
  Stream.Add('<public_url xmlns="urn:yandex:disk:meta">true</public_url>');
  Stream.Add('</prop>');
  Stream.Add('</set>');
  Stream.Add('</propertyupdate>');
  with http.Request do
    begin
      UserAgent             :=ApplicationName;
      ContentLength         :=Length(stream.GetText);
    end;
  Answer:=http.Prop(Id_HTTPMethodPropPatch,YaURL+FileName,Stream);
  Result:= Regex(Answer,'<public_url xmlns="urn:yandex:disk:meta">(.*?)</public_url>');
  FreeAndNil(Stream);
end;

function TYaDsk.IsShare(FileName: string):boolean;
var
  Answer,Res:String;
  Stream:TStringList;
 begin
  Stream:=TStringList.Create;
  Stream.Add('<propfind xmlns="DAV:">');
  Stream.Add('<prop>');
  Stream.Add('<public_url xmlns="urn:yandex:disk:meta"/>');
  Stream.Add('</prop>');
  Stream.Add('</propfind>');
  with http.Request do
    begin
      UserAgent             :=ApplicationName;
      CustomHeaders.AddValue('Depth','0');
      ContentLength         :=Length(stream.GetText);
    end;
  Answer:=http.Prop(Id_HTTPMethodPropFind,YaURL+FileName,Stream);
  Res:= Regex(Answer,'<d:status>(.*?)</d:status>');
  showmessage(res);
  FreeAndNil(Stream);
end;

{$ENDREGION}

procedure Register;
begin
  RegisterComponents('YaDsk', [TYaDsk]);
end;

end.
