using System;
using System.Collections;

namespace Json;

typealias JsonObject = Dictionary<StringView, JsonType>;
typealias JsonArray = List<JsonType>;

enum JsonType
{
	case Object(JsonObject value);
	case Array(JsonArray value);
	case String(String value);
	case Number(double value);
	case Bool(bool value);

	public JsonObject AsObject => this case .Object(let value) ? value : null;
	public List<JsonType> AsArray => this case .Array(let value) ? value : null;
	public String AsString => this case .String(let value) ? value : null;
	public double? AsNumber => this case .Number(let value) ? value : null;
	public bool? AsBool => this case .Bool(let value) ? value : null;

	public ref JsonType this[StringView key] => ref this.AsObject[key];
	public ref JsonType this[int index] => ref this.AsArray[index];
}

class Json
{
	public JsonObject Root;
	BumpAllocator allocator = new .() ~ delete _;

	public ref JsonType this[StringView key] => ref Root[key];

	public static Result<void, JsonError> Parse(StringView text, in Self json)
	{
		var remainingText = text;
		var root = Object(text, ref remainingText, json.allocator);

		if (root case .Ok)
		{
			json.Root = root;
			return .Ok;
		}

		switch (root)
		{
		case .Ok(let val):
			json.Root = root;
			return .Ok;
		case .Err(let err):
			return .Err(err);
		}
	}

	static Result<JsonObject, JsonError> Object(StringView fullText, ref StringView remainingText, BumpAllocator allocator)
	{
		Check!(Match(fullText, ref remainingText, '{'));
		MatchWhitespace(ref remainingText);

		var object = new:allocator JsonObject();

		while (remainingText.Length > 0)
		{
			StringView identifier = ?;

			switch (String(fullText, ref remainingText, allocator))
			{
			case .Ok(let val):
				identifier = val;
			case .Err:
				break;
			}

			MatchWhitespace(ref remainingText);
			Check!(Match(fullText, ref remainingText, ':'));
			MatchWhitespace(ref remainingText);

			if (Match(fullText, ref remainingText, "null") case .Err)
			{
				switch (Value(fullText, ref remainingText, allocator))
				{
				case .Ok(let val):
					object.Add(identifier, val);
				case .Err(let err):
					return .Err(err);
				}
			}

			MatchWhitespace(ref remainingText);
			if (Match(fullText, ref remainingText, ',') case .Err) break;
			MatchWhitespace(ref remainingText);
		}

		MatchWhitespace(ref remainingText);
		Check!(Match(fullText, ref remainingText, '}'));

		return .Ok(object);
	}

	// Escape sequences are unsupported.
	static Result<String, JsonError> String(StringView fullText, ref StringView remainingText, BumpAllocator allocator)
	{
		Check!(Match(fullText, ref remainingText, '"'));

		var stringView = remainingText;
		stringView.Length = 0;

		var isEscaped = false;
		while (remainingText.Length > 0)
		{
			if (remainingText[0] == '"' && !isEscaped)
				break;

			isEscaped = remainingText[0] == '\\';
			remainingText.RemoveFromStart(1);

			stringView.Length++;
		}

		Check!(Match(fullText, ref remainingText, '"'));

		var string = new:allocator String();
		String.Unescape(stringView.Ptr, stringView.Length, string);
		return string;
	}

	static Result<double, JsonError> Number(StringView fullText, ref StringView remainingText)
	{
		var numberView = remainingText;
		numberView.Length = 0;

		while (remainingText.Length > 0)
		{
			switch (remainingText[0])
			{
			case '0','1','2','3','4','5','6','7','8','9','-','.','+','e','E':
				remainingText.RemoveFromStart(1);
				numberView.Length++;
				continue;
			default:
			}

			break;
		}

		if (numberView.Length == 0)
			return .Err(.(fullText, remainingText, .Number));

		switch (double.Parse(numberView))
		{
		case .Ok(let val):
			return .Ok(val);
		case .Err:
			return .Err(.(fullText, remainingText, .Number));
		}
	}

	static Result<List<JsonType>, JsonError> Array(StringView fullText, ref StringView remainingText, BumpAllocator allocator)
	{
		Check!(Match(fullText, ref remainingText, '['));
		MatchWhitespace(ref remainingText);

		var array = new:allocator List<JsonType>();

		while (remainingText.Length > 0)
		{
			MatchWhitespace(ref remainingText);

			switch (Value(fullText, ref remainingText, allocator))
			{
			case .Ok(let val):
				array.Add(val);
			case .Err(let err):
				break;
			}

			MatchWhitespace(ref remainingText);
			if (Match(fullText, ref remainingText, ',') case .Err) break;
			MatchWhitespace(ref remainingText);
		}

		MatchWhitespace(ref remainingText);
		Check!(Match(fullText, ref remainingText, ']'));

		return .Ok(array);
	}

	static Result<bool, JsonError> Bool(StringView fullText, ref StringView remainingText)
	{
		if (Match(fullText, ref remainingText, "true") case .Ok)
		{
			return .Ok(true);
		}

		switch (Match(fullText, ref remainingText, "false"))
		{
		case .Ok:
			return .Ok(false);
		case .Err(let err):
			return .Err(err);
		}
	}

	static Result<JsonType, JsonError> Value(StringView fullText, ref StringView remainingText, BumpAllocator allocator)
	{
		if (remainingText[0] == '{')
		{
			switch (Object(fullText, ref remainingText, allocator))
			{
			case .Ok(let val):
				return .Ok(.Object(val));
			case .Err(let err):
				return .Err(err);
			}
		}

		if (remainingText[0] == '[')
		{
			switch (Array(fullText, ref remainingText, allocator))
			{
			case .Ok(let val):
				return .Ok(.Array(val));
			case .Err(let err):
				return .Err(err);
			}
		}

		if (remainingText[0] == '"')
		{
			switch (String(fullText, ref remainingText, allocator))
			{
			case .Ok(let val):
				return .Ok(.String(val));
			case .Err(let err):
				return .Err(err);
			}
		}

		var bool = Bool(fullText, ref remainingText);
		if (bool case .Ok) return .Ok(.Bool(bool.Value));

		switch (Number(fullText, ref remainingText))
		{
		case .Ok(let val):
			return .Ok(.Number(val));
		case .Err(let err):
			return .Err(err);
		}
	}

	static Result<void, JsonError> Match(StringView fullText, ref StringView remainingText, StringView string)
	{
		if (remainingText.Length >= string.Length && remainingText.Substring(0, string.Length) == string)
		{
			remainingText.RemoveFromStart(string.Length);
			return .Ok;
		}

		return .Err(.(fullText, remainingText, .String(string)));
	}

	static Result<void, JsonError> Match(StringView fullText, ref StringView remainingText, char8 char)
	{
		if (remainingText.Length > 0 && remainingText[0] == char)
		{
			remainingText.RemoveFromStart(1);
			return .Ok;
		}

		return .Err(.(fullText, remainingText, .Character(char)));
	}

	static void MatchWhitespace(ref StringView remainingText)
	{
		while (remainingText.Length > 0 && remainingText[0].IsWhiteSpace)
			remainingText.RemoveFromStart(1);
	}

	static mixin Check<T>(Result<T, JsonError> result, out T value)
	{
		switch (result)
		{
		case .Ok(let val):
			value = val;
		case .Err(let err):
			value = ?;
			return .Err(err);
		}
	}

	static mixin Check(Result<void, JsonError> result)
	{
		if (result case .Err(let err)) return .Err(err);
	}
}

struct JsonError
{
	public enum Expected
	{
		case String(StringView string);
		case Character(char8 char);
		case Number;
	}

	public StringView FullText;
	public StringView RemainingText;
	public Expected Expected;

	public this(StringView fullText, StringView remainingText, Expected expected)
	{
		FullText = fullText;
		RemainingText = remainingText;
		Expected = expected;
	}

	public override void ToString(String strBuffer)
	{
		var line = 1;

		let parsedLength = FullText.Length - RemainingText.Length;
		var lastNewlineIndex = 0;

		for (var i = 0; i < parsedLength; i++)
		{
			if (FullText[i] == '\n')
			{
				line++;
				lastNewlineIndex = i;
			}
		}

		let characterIndex = parsedLength - lastNewlineIndex;

		strBuffer..Append("Error parsing JSON line ")
			..Append(line)
			..Append(" character ")
			..Append(characterIndex)
			..Append(": expected ");

		switch (Expected)
		{
		case .String(let string):
			strBuffer..Append("string \"")
				..Append(string)
				..Append("\"");
		case .Character(let char):
			strBuffer..Append("character \"")
				..Append(char)
				..Append("\"");
		case .Number:
			strBuffer.Append("number");
		}

		strBuffer.Append(".");
	}
}