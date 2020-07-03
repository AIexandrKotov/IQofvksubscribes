program IQ;

{$reference 'System.Xml.dll'}
//отвечает за то, будет ли IQBase.xml вшит в .exe или же будет внешним файлом
{define IQBASERESOURCE}

uses System;
uses System.Collections.Generic;
uses System.IO;
uses System.Reflection;
uses System.Xml;

type
  Club = class
    public auto property Id: integer;
    public auto property Name: string;
    public auto property AvegageIQ: real;
    public auto property Influence: real;
    
    public constructor(reader: XmlReader);
    begin
      Id := reader.GetAttribute('Id').ToInteger();
      Name := reader.GetAttribute('Name');
      AvegageIQ := reader.GetAttribute('IQ').ToReal();
      Influence := reader.GetAttribute('Influence').ToReal();
    end;
  end;
  
  IQCounter = static class
    static IQs: Dictionary<integer, Club> := new Dictionary<integer, Club>();
    const Limit = 500;
    
    static constructor();
    begin
      {$ifdef IQBASERESOURCE}
        {$resource 'IQBase.xml'}
        var stream := GetResourceStream('IQBase.xml');
      {$else}
        var stream := &File.OpenRead('IQBase.xml');
      {$endif}
      var iqbase := new XmlTextReader(stream);
      iqbase.ReadToFollowing('IQBase');
      iqbase.ReadToDescendant('Subscribes');
      
      begin
        var subscribes := iqbase.ReadSubtree();
        subscribes.ReadToDescendant('Subscribe');
        repeat
          var clb := new Club(subscribes);
          IQs.Add(clb.Id, clb);
        until not subscribes.ReadToFollowing('Subscribe');
      end;
      iqbase.ReadEndElement();
      
      iqbase.Dispose();
      stream.Dispose();
    end;
    
    static function ParseSubscribe(str: string): integer;
    begin
      str := str.Remove('<div id="fans_idol_sub-');
      Result := str.Remove(str.IndexOf('"')).ToInteger();
    end;
    
    static function GetOrderInfluence(order: integer): real;
    begin
      case order of
        1..3: Result := 2.5;
        4..6: Result := 2;
        7..9: Result := 1.75;
        10..integer.MaxValue: Result := 1;
      end;
    end;
    
    static function GetSubscribes(html: array of string): List<ValueTuple<integer, real>>;
    begin
      Result := new List<ValueTuple<integer, real>>(500);
      var count := 0;
      html := html.ConvertAll(x -> x.Trim());
      foreach var str in html do
      begin
        if str.StartsWith('<div id="fans_idol_sub-') then
        begin
          count += 1;
          Result.Add(new ValueTuple<integer, real>(ParseSubscribe(str), GetOrderInfluence(count)));
        end;
        if count >= Limit then exit;
      end;
    end;
    
    static function GetFilename(filename: string) := &File.Exists(filename) ? filename : filename + '.html';
    
    public static function Count(filename: string): real;
    begin
      var subs := GetSubscribes(&File.ReadAllLines(GetFilename(filename))).Where(x -> IQs.ContainsKey(x.Item1)).Select(x -> new ValueTuple<Club, real>(IQs[x.Item1], x.Item2));
      var alliq := 0.0;
      var allinf := 0.0;
      foreach var sub in subs do
      begin
        alliq += sub.Item1.AvegageIQ * sub.Item1.Influence * sub.Item2;
        allinf += sub.Item1.Influence * sub.Item2;
      end;
      Result := Round(alliq / allinf, 2);
    end;
  end;

begin
  Writeln('Введите имя файла (для .html тип можно опустить):');
  while true do
  begin
    try
      var q := IQCounter.Count(ReadlnString());
      Writeln($'IQ: {q} ({Round((q-60)/80*100, 2)}%)');
    except
      on e: Exception do
      begin
        Writeln(E.GetType.Name);
      end;
    end;
  end;
end.