import 'package:flutter/material.dart';
import 'package:ai_sound_agent/app/route.dart';


class BreadcrumbTrail extends StatelessWidget {
  final AppRouteState state;
  
  const BreadcrumbTrail({super.key, required this.state});
  
  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        for (int i = 0; i < state.breadcrumbs.length; i++)
          GestureDetector(
            onTap: () => state.popTo(i),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.breadcrumbs[i],
                  style: TextStyle(
                    color: i == state.breadcrumbs.length - 1 
                      ? Colors.blue 
                      : Colors.grey,
                  ),
                ),
                if (i < state.breadcrumbs.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('>', style: TextStyle(color: Colors.grey)),
                  )
              ],
            ),
          ),
        ],
    );
  }
}