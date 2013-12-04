(*
	Tries with frequencies Mathematica package
    Copyright (C) 2013  Anton Antonov

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

	Written by Anton Antonov, 
	antononcube@gmail.com, 
	7320 Colbury Ave, 
	Windermere, Florida, USA.
*)

(*
    Mathematica is (C) Copyright 1988-2013 Wolfram Research, Inc.

    Protected by copyright law and international treaties.

    Unauthorized reproduction or distribution subject to severe civil
    and criminal penalties.

    Mathematica is a registered trademark of Wolfram Research, Inc.
*)

(* Version 0.8 *)
(* This version contains functions to build, shrink, and retrieve nodes of tries (also known as "prefix trees"). The implementations are geared toward utilization of data mining algorithms, like frequent sequence occurrences. *)
(* TODO: 
  1. Enhance the functionality of TriePosition to work over shrunk tries. 
  2. Enhance the signature and functionality of TrieLeafProbabilities to take a second argument of a "word" for which the leaf probabilities have to be found.
*)

BeginPackage["TriesWithFrequencies`"]

TriePosition::usage = "TriePosition[t_, w :(_String | _List)] gives the position node corresponding to the last \"character\" of the \"word\" w in the trie t. Strings are converted to lists first."

TrieRetrieve::usage = "TrieRetrieve[t_, w :(_String | _List)] gives the node corresponding to the last \"character\" of the \"word\" w in the trie t. Strings are converted to lists first."

TrieCreate::usage = "TrieCreate[words:{(_String|_List)..}] creates a trie from a list of strings or a list of lists."

TrieInsert::usage = "TrieInsert[t_, w : (_String | _List)] insert a \"word\" to the trie t. TrieInsert[t_, w : (_String | _List), val_] inserts a key and a corresponding value."

TrieMerge::usage = "TrieMerge[t1_, t2_] merges two tries."

TrieShrink::usage = "TrieShrink shrinks the leaves and internal nodes into prefixes."

TrieToRules::usage = "Converts a trie into a list of rules suitable for visualization with GraphPlot and LayeredGraphPlot. To each trie node is added a list of its level and its traversal order."

TrieForm::usage = "Shrinks the trie argument and returns a list of rules for a graph plot of it. In order to eliminate ambiguity each node is with its traversal order."

TrieNodeProbabilities::usage = "Converts the frequencies at the nodes of a trie into probabilities. The value of the option \"ProbabilityModifier\" is a function that is applied to the computed probabilities."

TrieLeafProbabilities::usage = "Gives the probabilities to end up at each of the leaves by paths from the root of the trie."

TrieLeafProbabilitiesWithPositions::usage = "Gives the probabilities to end up at each of the leaves by paths from the root of the trie. For each leaf its position in the trie is given."

TriePositionParts::usage = "Transforms a list of the form {a[1],a[2],...,a[n],1} into {{1}, {a[1],1}, {a[1],a[2],1}, ..., {a[1],a[2],...,a[n],1}}."

TriePathFromPosition::usage = "TriePathFromPosition[trie_,pos_] gives a list of nodes from the root of a trie to the node at a specified position."

Begin["`Private`"]


Clear[TriePosition]
TriePosition[t_, word_String] := TriePosition[t, Characters[word]];
TriePosition[t_, {}] := {};
TriePosition[{}, _] := {};
TriePosition[{_}, _] := {};
TriePosition[t_, chars_] :=
  Block[{i = 2},
   While[i <= Length[t] && t[[i, 1, 1]] =!= chars[[1]], i++];
   If[i > Length[t], {},
    Join[{i}, TriePosition[t[[i]], Rest[chars]]]
   ]
  ];

TrieRetrieve[t_, word_String] := TrieRetrieve[t, Characters[word]];
TrieRetrieve[t_, chars_] :=
  Block[{pos},
   pos = TriePosition[t, chars];
   Which[
    Length[pos] == 0, {},
    Length[pos] == Length[chars], t[[Sequence @@ pos, 1]],
    True, {}
   ]
  ];


Clear[MakeTrie]
MakeTrie[word_String] := MakeTrie[word, 1];
MakeTrie[word_String, v_Integer] := With[{chars = Characters[word]}, MakeTrie[chars,v]];
MakeTrie[chars_List] := MakeTrie[chars, 1];
MakeTrie[chars_List, v_Integer] := Fold[{{#2, v}, #1} &, {{Last[chars], v}}, Reverse@Most@chars];

Clear[TrieMerge]
TrieMerge[{}, {}] := {};
TrieMerge[t1_, t2_] :=
  Which[
   t1[[1, 1]] != t2[[1, 1]], {t1, t2},
   t1[[1, 1]] == t2[[1, 1]],
   Prepend[
    Join[
     Select[Rest[t1], ! MemberQ[Rest[t2][[All, 1, 1]], #[[1, 1]]] &],
     Select[Rest[t2], ! MemberQ[Rest[t1][[All, 1, 1]], #[[1, 1]]] &],
     DeleteCases[
      Flatten[
       Outer[If[#1[[1, 1]] == #2[[1, 1]], TrieMerge[#1, #2], {}] &, Rest[t1], Rest[t2], 1],
       1], {}]
     ], {t1[[1, 1]], t1[[1, 2]] + t2[[1, 2]]}],
   Rest[t1] === {}, t2,
   Rest[t2] === {}, t1
  ];

Clear[TrieInsert]

TrieInsert[t_, word : (_String | _List)] := TrieMerge[t, {{{}, 1}, MakeTrie[word]}];

TrieInsert[t_, wordKey : (_String | _List), value_] := 
  Block[{mt},
    mt = MakeTrie[wordKey,0];
    mt[[Sequence @@ Join[Table[2, {Depth[mt] - 3}], {1, 2}]]] = value;
    TrieMerge[t, {{{}, 0}, mt}]
  ];

TrieCreate[ {}] := {{{}, 0}}; 
TrieCreate[words : {(_String | _List) ...}] :=
  Fold[TrieInsert, {{{}, 1}, MakeTrie[First[words]]}, Rest@words];

Clear[TrieRemoveFrequencies]
TrieRemoveFrequencies[t_] :=
  Which[
   MatchQ[t, {_, _Integer}], t[[1]],
   MatchQ[t, {{_, _Integer}}], {t[[1, 1]]},
   MatchQ[t, {{_, _Integer}, ___}], 
   Prepend[TrieRemoveFrequencies /@ Rest[t], t[[1, 1]]]
  ];

Clear[NodeJoin]
NodeJoin[n_String] := n;
NodeJoin[n1_String, n2_String] := n1 <> n2;
NodeJoin[n1_, n2_String] := n2;
NodeJoin[n_] := TH[n];
NodeJoin[n1_TH, n2_TH] := TH @@ Join[n1, n2];
NodeJoin[n1_, n2_TH] := Join[TH[n1], n2];
NodeJoin[n1_, n2_] := TH[n1, n2];

Clear[TrieShrink, TrieShrinkRec];
TrieShrink[t_] := TrieShrinkRec[t] /. TH -> List;
TrieShrinkRec[{}] := {};
TrieShrinkRec[t_] :=
  Block[{tt, newnode, rootQ = (ListQ[t[[1, 1]]] && Length[t[[1, 1]]] == 0)},
   Which[
    ! rootQ && Length[t] == 1, {{NodeJoin[t[[1, 1]]], t[[1, 2]]}},
    ! rootQ && Length[t] == 2 && t[[1, 2]] == t[[2, 1, 2]],
    tt = TrieShrinkRec[t[[2]]];
    newnode = {NodeJoin[t[[1, 1]], tt[[1, 1]]], tt[[1, 2]]};
    If[Length[tt] == 1,
     {newnode},
     Prepend[Rest@tt, newnode]
    ],
    True,
    Prepend[TrieShrinkRec /@ Rest[t], 
     If[rootQ, t[[1]], {NodeJoin[t[[1, 1]]], t[[1, 2]]}]]
   ]
  ];

Clear[TrieMapAtNodes];
TrieMapAtNodes[{}] := {};
TrieMapAtNodes[func_, t_] :=
  Which[
   Length[t] == 1, func[t[[1]]],
   True,
   Prepend[TrieMapAtNodes[func, #] & /@ Rest[t], func[t[[1]]]]
  ];

Clear[TrieFold];
TrieFold[{}] := {};
TrieFold[func_, t_] :=
  Which[
   Length[t] == 1, {func[t]},
   True,
   Prepend[TrieFold[func, #] & /@ Rest[t], func[t]]
  ];


Clear[TrieToRules]
TrieToRules[tree_] := Block[{ORDER = 0}, TrieToRules[tree, 0, 0]];
TrieToRules[tree_, level_, order_] :=
  Block[{nodeRules},
   Which[
    tree === {}, {},
    Rest[tree] === {}, {},
    True,
    nodeRules = Map[{tree[[1]], {level, order}} -> {#[[1]], {level + 1, ORDER++}} &, Rest[tree], {1}];
    Join[
     nodeRules,
     Flatten[MapThread[TrieToRules[#1, level + 1, #2] &, {Rest[tree], nodeRules[[All, 2, 2, 2]]}], 1]
    ]
   ]
  ];

Clear[GrFramed]
GrFramed[text_] := 
  Framed[text, {Background -> RGBColor[1, 1, 0.8], 
    FrameStyle -> RGBColor[0.94, 0.85, 0.36], 
    FrameMargins -> Automatic}];

Clear[TrieForm]
TrieForm[mytrie_, opts:OptionsPattern[]] := 
  LayeredGraphPlot[TrieToRules[mytrie], 
   VertexRenderingFunction -> (Text[GrFramed[#2[[1]]], #1] &), opts];

TrieNodeProbabilities::ntnode = "Non trie node was encountered: `1`. A trie node has two elements prefix and frequency."

Clear[TrieNodeProbabilities, TrieNodeProbabilitiesRec]
Options[TrieNodeProbabilities] = {"ProbabilityModifier" -> N};
Options[TrieNodeProbabilitiesRec] = Options[TrieNodeProbabilities];
TrieNodeProbabilities[trie_, opts : OptionsPattern[]] :=
  ReplacePart[TrieNodeProbabilitiesRec[trie, opts], {1, 2} -> 1];
TrieNodeProbabilitiesRec[trie_, opts : OptionsPattern[]] :=  
  Block[{sum, res, pm = OptionValue["ProbabilityModifier"]},
   Which[
    Rest[trie] == {}, trie,
    True,
    If[trie[[1, 2]] == 0,
     sum = Total[Rest[trie][[All, 1, 2]]],
     sum = trie[[1, 2]],
     Message[TrieNodeProbabilities::ntnode,trie[[1]]];
     Return[{}]
    ];
    res = Map[TrieNodeProbabilitiesRec[#, opts] &, Rest[trie]];
    res[[All, 1, 2]] = Map[pm, res[[All, 1, 2]]/sum];
    Prepend[res, First[trie]]
   ]
  ];


TrieLeafProbabilities::ntnode = "Non trie node was encountered: `1`. A trie node has two elements prefix and frequency."
TrieLeafProbabilitiesWithPositions::ntnode = "Non trie node was encountered: `1`. A trie node has two elements prefix and frequency."

Clear[TrieLeafProbabilities]
TrieLeafProbabilities[trieArg_] :=
  Block[{TrieLeafProbabilitiesRec},
   
   TrieLeafProbabilitiesRec[trie_] :=
    Block[{res, sum},
     Which[
      Rest[trie] == {}, trie,
      True,
      sum = Total[Rest[trie][[All, 1, 2]]];
      res = Map[TrieLeafProbabilitiesRec[#] &, Rest[trie]];
      If[sum < 1, res = Append[res, {{trie[[1, 1]], 1 - sum}}]];
      res = Map[{#[[1]], #[[2]]*trie[[1, 2]]} &, Flatten[res, 1]]
     ]
    ];
   
   If[trieArg[[1, 2]] == 0,
    TrieLeafProbabilitiesRec[trieArg],  
    Map[{#[[1]], #[[2]]} &, TrieLeafProbabilitiesRec[trieArg]],
    Message[TrieLeafProbabilities::ntnode,trieArg[[1]]];
    Return[{}]
   ]
  ];

Clear[TrieLeafProbabilitiesWithPositions]
TrieLeafProbabilitiesWithPositions[trieArg_] :=
  Block[{TrieLeafProbabilitiesRec},

   TrieLeafProbabilitiesRec[trie_] :=
    Block[{res, sum},
     Which[
      Rest[trie] === {}, {Append[trie[[1]], {1}]},
      True,
      sum = Total[Rest[trie][[All, 1, 2]]];
      res = Map[TrieLeafProbabilitiesRec[#] &, Rest[trie]];
      res =
       MapThread[
        Function[{r, ind},
         Map[Append[Most[#], Prepend[#[[-1]], ind]] &, r]
         ], {res, Range[2, Length[trie]]}];
      If[sum < 1, res = Append[res, {{trie[[1, 1]], 1 - sum, {1}}}]];
      res = Map[{#[[1]], #[[2]]*trie[[1, 2]], #[[3]]} &, Flatten[res, 1]]
      ]
     ];
   
   If[trieArg[[1, 2]] == 0,
    TrieLeafProbabilitiesRec[trieArg],
    Map[{#[[1]], #[[2]], #[[3]]} &, TrieLeafProbabilitiesRec[trieArg]],
    Message[TrieLeafProbabilitiesWithPositions::ntnode,trieArg[[1]]];
    Return[{}]
   ]
  ];

Clear[TriePositionParts]
TriePositionParts[pos : {_Integer ..}] := 
  Map[Append[#, 1] &, FoldList[Join[#1, {#2}] &, {}, Most[pos]]];

Clear[TriePathFromPosition]
TriePathFromPosition[trie_, pos : {_Integer ...}] :=
  Block[{ps},
   ps = FoldList[Append[#1, #2] &, {First[pos]}, Rest[pos]];
   Fold[Append[#1, trie[[Sequence @@ Append[#2, 1]]]] &, {}, Most[ps]]
  ];

End[]

EndPackage[]