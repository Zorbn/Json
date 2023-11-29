using System;
using System.IO;

namespace Json;

class Tests
{
	[Test]
	static void Simple()
	{
		let jsonText = """
		{
			"string": "hi",
			"escapedString": "\\"hi\\"",
			"anotherString": "good",
			"newObject": {
				"moreStuff": [1.0, 2.0, 3.0, 777.0]
			},
			"aBool": true,
			"other": null
		}
		""";

		let json = scope Json();
		Json.Parse(jsonText, json);

		Test.Assert(json["newObject"]["moreStuff"][0].AsNumber == 1.0);
		Test.Assert(json["newObject"]["moreStuff"].AsArray.Count == 4);
		Test.Assert(json["string"].AsString == "hi");
		Test.Assert(json["escapedString"].AsString == "\"hi\"");
	}

	[Test]
	static void Ldtk()
	{
		let jsonText = """
		{
			"__identifier": "CopperOre",
			"__grid": [3,9],
			"__pivot": [0,0],
			"__tags": [],
			"__tile": { "tilesetUid": 1, "x": 8, "y": 16, "w": 16, "h": 8 },
			"__smartColor": "#BE4A2F",
			"iid": "d383d9d0-c640-11ed-8173-c74908fd845f",
			"width": 16,
			"height": 8,
			"defUid": 5,
			"px": [24,72],
			"fieldInstances": []
		}
		""";

		let json = scope Json();
		Json.Parse(jsonText, json);

		Test.Assert(json.Root["px"].AsArray[0].AsNumber == 24);
		Test.Assert(json["px"][1].AsNumber == 72);
	}
}