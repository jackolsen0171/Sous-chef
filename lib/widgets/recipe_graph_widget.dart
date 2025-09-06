import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../models/recipe_graph.dart';

class RecipeGraphWidget extends StatefulWidget {
  final RecipeGraph recipeGraph;

  const RecipeGraphWidget({
    Key? key,
    required this.recipeGraph,
  }) : super(key: key);

  @override
  State<RecipeGraphWidget> createState() => _RecipeGraphWidgetState();
}

class _RecipeGraphWidgetState extends State<RecipeGraphWidget> {
  late Graph graph;
  late BuchheimWalkerConfiguration builder;

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  @override
  void didUpdateWidget(RecipeGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipeGraph != widget.recipeGraph) {
      _buildGraph();
    }
  }

  void _buildGraph() {
    graph = Graph()..isTree = false;
    builder = BuchheimWalkerConfiguration()
      ..siblingSeparation = (100)
      ..levelSeparation = (150)
      ..subtreeSeparation = (150)
      ..orientation = (BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM);

    // Add nodes
    for (final recipeNode in widget.recipeGraph.nodes) {
      final node = Node.Id(recipeNode.id);
      graph.addNode(node);
    }

    // Add edges
    for (final recipeEdge in widget.recipeGraph.edges) {
      final fromNode = Node.Id(recipeEdge.from);
      final toNode = Node.Id(recipeEdge.to);
      graph.addEdge(fromNode, toNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.5,
        maxScale: 2.0,
        child: GraphView(
          graph: graph,
          algorithm: BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder)),
          paint: Paint()
            ..color = Colors.green
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
          builder: (Node node) {
            final nodeId = node.key!.value as String;
            final recipeNode = widget.recipeGraph.nodes.firstWhere(
              (n) => n.id == nodeId,
            );

            return _buildNodeWidget(recipeNode);
          },
        ),
      ),
    );
  }

  Widget _buildNodeWidget(RecipeNode node) {
    Color nodeColor;
    IconData nodeIcon;
    double nodeWidth = 120;

    switch (node.type) {
      case NodeType.ingredient:
        nodeColor = Colors.green.shade100;
        nodeIcon = Icons.eco;
        nodeWidth = 100;
        break;
      case NodeType.process:
        nodeColor = Colors.blue.shade100;
        nodeIcon = Icons.psychology;
        nodeWidth = 100;
        break;
      case NodeType.result:
        nodeColor = Colors.orange.shade100;
        nodeIcon = Icons.restaurant;
        nodeWidth = 140;
        break;
    }

    return Container(
      width: nodeWidth,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: nodeColor,
        border: Border.all(
          color: nodeColor.withOpacity(0.7),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            nodeIcon,
            color: _getIconColor(node.type),
            size: node.type == NodeType.result ? 24 : 20,
          ),
          const SizedBox(height: 4),
          Text(
            node.label,
            style: TextStyle(
              fontSize: node.type == NodeType.result ? 12 : 10,
              fontWeight: node.type == NodeType.result 
                  ? FontWeight.bold 
                  : FontWeight.w500,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _getIconColor(NodeType type) {
    switch (type) {
      case NodeType.ingredient:
        return Colors.green.shade700;
      case NodeType.process:
        return Colors.blue.shade700;
      case NodeType.result:
        return Colors.orange.shade700;
    }
  }
}