#!/bin/bash
cp topology.dot graph.dot
sed -i 's/:"swp/:"/g' graph.dot
sed -i 's/graph vx {/graph vx {\n  graph [fontsize=8 fontname=Verdana compound=true];\n  node [shape=box style=filled]\n\n\n    { rank=same leaf01 leaf02 }\n      { rank=same spine01 spine02 }\n        { rank=same exit01 exit02 }\n	  { rank=max "oob-mgmt-server" "oob-mgmt-switch" }\n/g' graph.dot
dot -Tpng -ograph.png graph.dot
rm graph.dot
