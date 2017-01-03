// azul4d
// Copyright © 2016 Ken Arroyo Ohori
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#include "CppLink.hpp"

Mesh_d CppLink::refine(Polygon_d &polygon, double ratio, double size) {
  Mesh_d polygon_refined;
    
  // Plane passing through points 0-2 is defined by the space of vector_01 and vector_02
  CGAL::Point_d<Kernel> origin = polygon.vertices[0];
  CGAL::Vector_d<Kernel> vector_01 = polygon.vertices[1]-origin;
  vector_01 /= sqrt(vector_01.squared_length());
  
  CGAL::Hyperplane_d<Kernel> orthogonal_to_vector_01(origin, vector_01.direction());
  double k = (orthogonal_to_vector_01.coefficient(0)*polygon.vertices[2][0]+orthogonal_to_vector_01.coefficient(1)*polygon.vertices[2][1]+orthogonal_to_vector_01.coefficient(2)*polygon.vertices[2][2]+orthogonal_to_vector_01.coefficient(3)*polygon.vertices[2][3]+orthogonal_to_vector_01.coefficient(4))/(orthogonal_to_vector_01.coefficient(0)*orthogonal_to_vector_01.coefficient(0)+orthogonal_to_vector_01.coefficient(1)*orthogonal_to_vector_01.coefficient(1)+orthogonal_to_vector_01.coefficient(2)*orthogonal_to_vector_01.coefficient(2)+orthogonal_to_vector_01.coefficient(3)*orthogonal_to_vector_01.coefficient(3));
  double point_2_projected_to_plane_coordinates[4] = {polygon.vertices[2][0]-k*orthogonal_to_vector_01.coefficient(0),
    polygon.vertices[2][1]-k*orthogonal_to_vector_01.coefficient(1),
    polygon.vertices[2][2]-k*orthogonal_to_vector_01.coefficient(2),
    polygon.vertices[2][3]-k*orthogonal_to_vector_01.coefficient(3)};
  CGAL::Point_d<Kernel> point_2_projected_to_plane(4, point_2_projected_to_plane_coordinates, point_2_projected_to_plane_coordinates+4);
  CGAL::Vector_d<Kernel> vector_02 = point_2_projected_to_plane-origin;
  vector_02 /= sqrt(vector_02.squared_length());
  
  // Project a polygon to the plane
  Polygon_d polygon_2d;
  for (auto point : polygon.vertices) {
    CGAL::Vector_d<Kernel> point_vector = point-origin;
    double coordinates_2d[2] = {point_vector*vector_01, point_vector*vector_02};
    polygon_2d.vertices.push_back(CGAL::Point_d<Kernel>(2, coordinates_2d, coordinates_2d+2));
  }
  
  // Refine it
  CDT triangulation;
  for (unsigned int index = 0; index < polygon_2d.vertices.size()-1; ++index) {
    CDT::Vertex_handle current_vertex = triangulation.insert(CDT::Point(polygon_2d.vertices[index][0], polygon_2d.vertices[index][1]));
    CDT::Vertex_handle next_vertex = triangulation.insert(CDT::Point(polygon_2d.vertices[index+1][0], polygon_2d.vertices[index+1][1]));
    triangulation.insert_constraint(current_vertex, next_vertex);
  } CDT::Vertex_handle last_vertex = triangulation.insert(CDT::Point(polygon_2d.vertices.back()[0], polygon_2d.vertices.back()[1]));
  CDT::Vertex_handle first_vertex = triangulation.insert(CDT::Point(polygon_2d.vertices.front()[0], polygon_2d.vertices.front()[1]));
  triangulation.insert_constraint(last_vertex, first_vertex);
  //    std::cout << "Before: " << triangulation.number_of_vertices();
  CGAL::refine_Delaunay_mesh_2(triangulation, CGAL::Delaunay_mesh_size_criteria_2<CDT>(ratio, size));
  //    std::cout << " After: " << triangulation.number_of_vertices() << std::endl;
  
  // Project the refined mesh back
  for (auto current_face = triangulation.finite_faces_begin(); current_face != triangulation.finite_faces_end(); ++current_face) {
    polygon_refined.triangles.push_back(Triangle_d());
    polygon_refined.triangles.back().vertices[0] = origin+current_face->vertex(0)->point()[0]*vector_01+current_face->vertex(0)->point()[1]*vector_02;
    polygon_refined.triangles.back().vertices[1] = origin+current_face->vertex(1)->point()[0]*vector_01+current_face->vertex(1)->point()[1]*vector_02;
    polygon_refined.triangles.back().vertices[2] = origin+current_face->vertex(2)->point()[0]*vector_01+current_face->vertex(2)->point()[1]*vector_02;
  }
    
  return polygon_refined;
}

std::vector<Edge_d> CppLink::generateEdges(std::vector<Polygon_d> &model) {
  
  // Generate a unique set of edges
  std::map<CGAL::Point_d<Kernel>, std::set<CGAL::Point_d<Kernel>>> uniqueEdges;
  for (auto const &polygon: model) {
    std::vector<CGAL::Point_d<Kernel>>::const_iterator previousVertex = polygon.vertices.begin();
    std::vector<CGAL::Point_d<Kernel>>::const_iterator currentVertex = previousVertex;
    ++currentVertex;
    while (currentVertex != polygon.vertices.end()) {
      uniqueEdges[*previousVertex].insert(*currentVertex);
      ++previousVertex;
      ++currentVertex;
    }
  }
  
  std::vector<Edge_d> edges;
  CGAL::Vector_d<Kernel>::FT splitEvery = 0.3;
  
  for (auto const &edgeStart: uniqueEdges) {
    for (auto const &edgeEnd: edgeStart.second) {
//      std::cout << "Start: " << edgeStart.first << std::endl;
//      std::cout << "End: " << edgeEnd << std::endl;
      CGAL::Vector_d<Kernel> edge = edgeEnd-edgeStart.first;
      CGAL::Vector_d<Kernel>::FT edgeNorm = sqrt(edge.squared_length());
//      std::cout << "Edge vector: " << edge << " with norm: " << edgeNorm << std::endl;
      CGAL::Vector_d<Kernel> edgeIncrement = (splitEvery/edgeNorm)*edge;
      unsigned int increments = floor(edgeNorm/splitEvery);
//      std::cout << "Increment vector: " << edgeIncrement << " with norm: " << sqrt(edgeIncrement.squared_length()) << std::endl;
//      std::cout << "Increments: " << increments << std::endl;
      edges.push_back(Edge_d());
      for (unsigned int currentIncrement = 0; currentIncrement <= increments; ++currentIncrement) {
        edges.back().vertices.push_back(edgeStart.first+currentIncrement*edgeIncrement);
//        std::cout << "\t" << edges.back().vertices.back() << std::endl;
      } if (edges.back().vertices.back() != edgeEnd) {
        edges.back().vertices.push_back(edgeEnd);
//        std::cout << "\t" << edges.back().vertices.back() << std::endl;
      }
    }
  }
  
  return edges;
}

std::vector<CGAL::Point_d<Kernel>> CppLink::generateVertices(std::vector<Polygon_d> &model) {
  std::vector<CGAL::Point_d<Kernel>> vertices;
  std::set<CGAL::Point_d<Kernel>> uniqueVertices;
  for (auto const &polygon: model) {
    for (auto const &vertex: polygon.vertices) {
      uniqueVertices.insert(vertex);
      vertices.push_back(vertex);
    }
  } return vertices;
}

Mesh_d CppLink::triangulateUsingBarycentre(Polygon_d &polygon) {
  
  Mesh_d polygon_triangulated;
  
  // Compute the centroid
  double centroid[4] = {0.0, 0.0, 0.0, 0.0};
  for (auto const &point : polygon.vertices) {
    for (unsigned int currentCoordinate = 0; currentCoordinate < 4; ++currentCoordinate) {
      centroid[currentCoordinate] += point.cartesian(currentCoordinate);
    }
  } for (unsigned int currentCoordinate = 0; currentCoordinate < 4; ++currentCoordinate) {
    centroid[currentCoordinate] /= polygon.vertices.size();
  } CGAL::Point_d<Kernel> centroidPoint(4, centroid, centroid+4);
  
  // Barycentric triangulation
  std::vector<CGAL::Point_d<Kernel>>::const_iterator previousPoint = polygon.vertices.begin();
  std::vector<CGAL::Point_d<Kernel>>::const_iterator currentPoint = previousPoint;
  ++currentPoint;
  while (currentPoint != polygon.vertices.end()) {
    polygon_triangulated.triangles.push_back(Triangle_d());
    polygon_triangulated.triangles.back().vertices[0] = centroidPoint;
    polygon_triangulated.triangles.back().vertices[1] = *previousPoint;
    polygon_triangulated.triangles.back().vertices[2] = *currentPoint;
    ++previousPoint;
    ++currentPoint;
  } polygon_triangulated.triangles.push_back(Triangle_d());
  polygon_triangulated.triangles.back().vertices[0] = centroidPoint;
  polygon_triangulated.triangles.back().vertices[1] = polygon.vertices.back();
  polygon_triangulated.triangles.back().vertices[2] = polygon.vertices.front();
  
  return polygon_triangulated;
}

Mesh_d CppLink::triangulateQuad(Polygon_d &polygon) {
  
  Mesh_d polygon_triangulated;
  
  // Barycentric triangulation
  CGAL::Point_d<Kernel> points[4];
  for (unsigned int currentIndex = 0; currentIndex < 4; ++currentIndex) {
    points[currentIndex] = polygon.vertices[currentIndex];
  }
  
  polygon_triangulated.triangles.push_back(Triangle_d());
  polygon_triangulated.triangles.back().vertices[0] = points[0];
  polygon_triangulated.triangles.back().vertices[1] = points[1];
  polygon_triangulated.triangles.back().vertices[2] = points[2];
  
  polygon_triangulated.triangles.push_back(Triangle_d());
  polygon_triangulated.triangles.back().vertices[0] = points[2];
  polygon_triangulated.triangles.back().vertices[1] = points[3];
  polygon_triangulated.triangles.back().vertices[2] = points[0];
  
  return polygon_triangulated;
}

void CppLink::makeTesseract() {
  std::vector<Polygon_d> tesseract;
  
  double coordinates_0000[4] = {-1, -1, -1, -1};
  double coordinates_0001[4] = {-1, -1, -1, +1};
  double coordinates_0010[4] = {-1, -1, +1, -1};
  double coordinates_0011[4] = {-1, -1, +1, +1};
  double coordinates_0100[4] = {-1, +1, -1, -1};
  double coordinates_0101[4] = {-1, +1, -1, +1};
  double coordinates_0110[4] = {-1, +1, +1, -1};
  double coordinates_0111[4] = {-1, +1, +1, +1};
  double coordinates_1000[4] = {+1, -1, -1, -1};
  double coordinates_1001[4] = {+1, -1, -1, +1};
  double coordinates_1010[4] = {+1, -1, +1, -1};
  double coordinates_1011[4] = {+1, -1, +1, +1};
  double coordinates_1100[4] = {+1, +1, -1, -1};
  double coordinates_1101[4] = {+1, +1, -1, +1};
  double coordinates_1110[4] = {+1, +1, +1, -1};
  double coordinates_1111[4] = {+1, +1, +1, +1};
  
  
  
  CGAL::Point_d<Kernel> point_0000(4, coordinates_0000, coordinates_0000+4);
  CGAL::Point_d<Kernel> point_0001(4, coordinates_0001, coordinates_0001+4);
  CGAL::Point_d<Kernel> point_0010(4, coordinates_0010, coordinates_0010+4);
  CGAL::Point_d<Kernel> point_0011(4, coordinates_0011, coordinates_0011+4);
  CGAL::Point_d<Kernel> point_0100(4, coordinates_0100, coordinates_0100+4);
  CGAL::Point_d<Kernel> point_0101(4, coordinates_0101, coordinates_0101+4);
  CGAL::Point_d<Kernel> point_0110(4, coordinates_0110, coordinates_0110+4);
  CGAL::Point_d<Kernel> point_0111(4, coordinates_0111, coordinates_0111+4);
  CGAL::Point_d<Kernel> point_1000(4, coordinates_1000, coordinates_1000+4);
  CGAL::Point_d<Kernel> point_1001(4, coordinates_1001, coordinates_1001+4);
  CGAL::Point_d<Kernel> point_1010(4, coordinates_1010, coordinates_1010+4);
  CGAL::Point_d<Kernel> point_1011(4, coordinates_1011, coordinates_1011+4);
  CGAL::Point_d<Kernel> point_1100(4, coordinates_1100, coordinates_1100+4);
  CGAL::Point_d<Kernel> point_1101(4, coordinates_1101, coordinates_1101+4);
  CGAL::Point_d<Kernel> point_1110(4, coordinates_1110, coordinates_1110+4);
  CGAL::Point_d<Kernel> point_1111(4, coordinates_1111, coordinates_1111+4);
  
  // ffvv
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0000);
  tesseract.back().vertices.push_back(point_0001);
  tesseract.back().vertices.push_back(point_0011);
  tesseract.back().vertices.push_back(point_0010);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0100);
  tesseract.back().vertices.push_back(point_0101);
  tesseract.back().vertices.push_back(point_0111);
  tesseract.back().vertices.push_back(point_0110);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_1000);
  tesseract.back().vertices.push_back(point_1001);
  tesseract.back().vertices.push_back(point_1011);
  tesseract.back().vertices.push_back(point_1010);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_1100);
  tesseract.back().vertices.push_back(point_1101);
  tesseract.back().vertices.push_back(point_1111);
  tesseract.back().vertices.push_back(point_1110);
  
  // fvfv
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0000);
  tesseract.back().vertices.push_back(point_0001);
  tesseract.back().vertices.push_back(point_0101);
  tesseract.back().vertices.push_back(point_0100);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0010);
  tesseract.back().vertices.push_back(point_0011);
  tesseract.back().vertices.push_back(point_0111);
  tesseract.back().vertices.push_back(point_0110);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_1000);
  tesseract.back().vertices.push_back(point_1001);
  tesseract.back().vertices.push_back(point_1101);
  tesseract.back().vertices.push_back(point_1100);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_1010);
  tesseract.back().vertices.push_back(point_1011);
  tesseract.back().vertices.push_back(point_1111);
  tesseract.back().vertices.push_back(point_1110);
  
  // fvvf
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0000);
  tesseract.back().vertices.push_back(point_0010);
  tesseract.back().vertices.push_back(point_0110);
  tesseract.back().vertices.push_back(point_0100);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0001);
  tesseract.back().vertices.push_back(point_0011);
  tesseract.back().vertices.push_back(point_0111);
  tesseract.back().vertices.push_back(point_0101);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_1000);
  tesseract.back().vertices.push_back(point_1010);
  tesseract.back().vertices.push_back(point_1110);
  tesseract.back().vertices.push_back(point_1100);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_1001);
  tesseract.back().vertices.push_back(point_1011);
  tesseract.back().vertices.push_back(point_1111);
  tesseract.back().vertices.push_back(point_1101);
  
  // vffv
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0000);
  tesseract.back().vertices.push_back(point_0001);
  tesseract.back().vertices.push_back(point_1001);
  tesseract.back().vertices.push_back(point_1000);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0010);
  tesseract.back().vertices.push_back(point_0011);
  tesseract.back().vertices.push_back(point_1011);
  tesseract.back().vertices.push_back(point_1010);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0100);
  tesseract.back().vertices.push_back(point_0101);
  tesseract.back().vertices.push_back(point_1101);
  tesseract.back().vertices.push_back(point_1100);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0110);
  tesseract.back().vertices.push_back(point_0111);
  tesseract.back().vertices.push_back(point_1111);
  tesseract.back().vertices.push_back(point_1110);
  
  // vfvf
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0000);
  tesseract.back().vertices.push_back(point_0010);
  tesseract.back().vertices.push_back(point_1010);
  tesseract.back().vertices.push_back(point_1000);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0001);
  tesseract.back().vertices.push_back(point_0011);
  tesseract.back().vertices.push_back(point_1011);
  tesseract.back().vertices.push_back(point_1001);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0100);
  tesseract.back().vertices.push_back(point_0110);
  tesseract.back().vertices.push_back(point_1110);
  tesseract.back().vertices.push_back(point_1100);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0101);
  tesseract.back().vertices.push_back(point_0111);
  tesseract.back().vertices.push_back(point_1111);
  tesseract.back().vertices.push_back(point_1101);
  
  // vvff
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0000);
  tesseract.back().vertices.push_back(point_0100);
  tesseract.back().vertices.push_back(point_1100);
  tesseract.back().vertices.push_back(point_1000);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0001);
  tesseract.back().vertices.push_back(point_0101);
  tesseract.back().vertices.push_back(point_1101);
  tesseract.back().vertices.push_back(point_1001);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0010);
  tesseract.back().vertices.push_back(point_0110);
  tesseract.back().vertices.push_back(point_1110);
  tesseract.back().vertices.push_back(point_1010);
  
  tesseract.push_back(Polygon_d());
  tesseract.back().vertices.push_back(point_0011);
  tesseract.back().vertices.push_back(point_0111);
  tesseract.back().vertices.push_back(point_1111);
  tesseract.back().vertices.push_back(point_1011);
  
  std::vector<Mesh_d> tesseract_refined;
  for (auto &polygon : tesseract) {
//    tesseract_refined.push_back(refine(polygon, 0.125, 0.1));
    tesseract_refined.push_back(triangulateQuad(polygon));
    tesseract_refined.back().colour[0] = 0.0;
    tesseract_refined.back().colour[1] = 0.0;
    tesseract_refined.back().colour[2] = 1.0;
    tesseract_refined.back().colour[3] = 0.2;
  } faces = tesseract_refined;
  edges = generateEdges(tesseract);
  vertices = generateVertices(tesseract);
}

void CppLink::makeHouse() {
  
  std::vector<Polygon_d> house;
  
  double point_coordinates[][4] = {
    {-1, -1, -1, -1}, // 0
    {1, -1, -1, -1}, // 1
    {-1, 1, -1, -1}, // 2
    {1, 1, -1, -1}, // 3
    {-1, -1, 1, -1}, // 4
    {1, -1, 1, -1}, // 5
    {-1, 1, 1, -1}, // 6
    {1, 1, 1, -1}, // 7 -- end of first house
    
    {-1, -1, -1, 1}, // 8
    {1, -1, -1, 1}, // 9
    {-1, 1, -1, 1}, // 10
    {1, 1, -1, 1}, // 11
    {-1, -1, 1, 1}, // 12
    {1, -1, 1, 1}, // 13
    {-1, 1, 1, 1}, // 14
    {1, 1, 1, 1}, // 15 -- end of base of second house
    
    {0, 0, 2, 3}, // 16 -- top of the roof
    
    {-0.5, -1, -1, 1}, // 17
    {-0.5, -1, 0.5, 1}, // 18
    {0, -1, 0.5, 1}, // 19
    {0, -1, -1, 1}, // 20 -- door for second house
    
    {0.25, -1, -0.5, 1}, // 21
    {0.25, -1, 0.5, 1}, // 22
    {0.75, -1, 0.5, 1}, // 23
    {0.75, -1, -0.5, 1} // 24 -- window 1
  };
  
  std::map<int, std::tuple<double, double, double>> materials;
  std::vector<int> materialOfFace;
  materials[0] = std::tuple<double, double, double>(0.7, 0.7, 0.7); // 0 -- walls
  materials[1] = std::tuple<double, double, double>(1.0, 0.0, 0.0); // 1 -- roof
  materials[2] = std::tuple<double, double, double>(0.7, 0.35, 0.17); // 2 -- door
  materials[3] = std::tuple<double, double, double>(0.0, 1.0, 0.0); // 3 -- grass
  materials[4] = std::tuple<double, double, double>(0.0, 1.0, 0.0); // 4 -- base
  materials[5] = std::tuple<double, double, double>(0.0, 0.0, 0.0); // 5 -- edges
  materials[6] = std::tuple<double, double, double>(0.3, 0.3, 1.0); // 6 -- window
  
  std::vector<CGAL::Point_d<Kernel>> points;
  for (int i = 0; i < 25; ++i) {
    points.push_back(CGAL::Point_d<Kernel>(4, point_coordinates[i], point_coordinates[i]+4));
  }
  
  // 0: Base of first house
  materialOfFace.push_back(4);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[0]);
  house.back().vertices.push_back(points[1]);
  house.back().vertices.push_back(points[3]);
  house.back().vertices.push_back(points[2]);
  
  // 1: Back of first house
  materialOfFace.push_back(0);
	house.push_back(Polygon_d());
  house.back().vertices.push_back(points[2]);
  house.back().vertices.push_back(points[3]);
  house.back().vertices.push_back(points[7]);
  house.back().vertices.push_back(points[6]);
  
  // 2: Left of first house
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[0]);
  house.back().vertices.push_back(points[2]);
  house.back().vertices.push_back(points[6]);
  house.back().vertices.push_back(points[4]);
  
  // 3: Front of first house
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[0]);
  house.back().vertices.push_back(points[1]);
  house.back().vertices.push_back(points[5]);
  house.back().vertices.push_back(points[4]);
  
  // 4: Right of first house
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[1]);
  house.back().vertices.push_back(points[3]);
  house.back().vertices.push_back(points[7]);
  house.back().vertices.push_back(points[5]);
  
  // 5: Top of first house
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[4]);
  house.back().vertices.push_back(points[5]);
  house.back().vertices.push_back(points[7]);
  house.back().vertices.push_back(points[6]);
  
  // 6: Base of second house
  materialOfFace.push_back(4);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[8]);
  house.back().vertices.push_back(points[9]);
  house.back().vertices.push_back(points[11]);
  house.back().vertices.push_back(points[10]);
  
  // 7: Back of second house
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[10]);
  house.back().vertices.push_back(points[11]);
  house.back().vertices.push_back(points[15]);
  house.back().vertices.push_back(points[14]);
  
  // 8: Left of second house
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[8]);
  house.back().vertices.push_back(points[10]);
  house.back().vertices.push_back(points[14]);
  house.back().vertices.push_back(points[12]);
  
  // 9: Front of second house (one piece)
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[8]);
  house.back().vertices.push_back(points[17]);
  house.back().vertices.push_back(points[18]);
  house.back().vertices.push_back(points[19]);
  house.back().vertices.push_back(points[20]);
  house.back().vertices.push_back(points[9]);
  house.back().vertices.push_back(points[13]);
  house.back().vertices.push_back(points[12]);
  
  // 9: Front of second house (by parts)
//  materialOfFace.push_back(0);
//  house.push_back(Polygon_d());
//  house.back().vertices.push_back(points[12]);
//  house.back().vertices.push_back(points[13]);
//  house.back().vertices.push_back(points[23]);
//  house.back().vertices.push_back(points[18]);
//  materialOfFace.push_back(0);
//  house.push_back(Polygon_d());
//  house.back().vertices.push_back(points[12]);
//  house.back().vertices.push_back(points[18]);
//  house.back().vertices.push_back(points[17]);
//  house.back().vertices.push_back(points[8]);
//  materialOfFace.push_back(0);
//  house.push_back(Polygon_d());
//  house.back().vertices.push_back(points[19]);
//  house.back().vertices.push_back(points[22]);
//  house.back().vertices.push_back(points[21]);
//  house.back().vertices.push_back(points[20]);
//  materialOfFace.push_back(0);
//  house.push_back(Polygon_d());
//  house.back().vertices.push_back(points[20]);
//  house.back().vertices.push_back(points[21]);
//  house.back().vertices.push_back(points[24]);
//  house.back().vertices.push_back(points[9]);
//  materialOfFace.push_back(0);
//  house.push_back(Polygon_d());
//  house.back().vertices.push_back(points[9]);
//  house.back().vertices.push_back(points[24]);
//  house.back().vertices.push_back(points[23]);
//  house.back().vertices.push_back(points[13]);
  
  //10: Right of second house
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[9]);
  house.back().vertices.push_back(points[11]);
  house.back().vertices.push_back(points[15]);
  house.back().vertices.push_back(points[13]);
  
  //11: Front top of the second house
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[12]);
  house.back().vertices.push_back(points[13]);
  house.back().vertices.push_back(points[16]);
  
  //12: Left top of the second house
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[12]);
  house.back().vertices.push_back(points[14]);
  house.back().vertices.push_back(points[16]);
  
  //13: Back top of the second house
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[14]);
  house.back().vertices.push_back(points[15]);
  house.back().vertices.push_back(points[16]);
  
  //14: Right top of the second house
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[13]);
  house.back().vertices.push_back(points[15]);
  house.back().vertices.push_back(points[16]);
  
  //15: Front down edge
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[0]);
  house.back().vertices.push_back(points[1]);
  house.back().vertices.push_back(points[9]);
  house.back().vertices.push_back(points[8]);
  
  //16: Left down edge
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[0]);
  house.back().vertices.push_back(points[2]);
  house.back().vertices.push_back(points[10]);
  house.back().vertices.push_back(points[8]);
  
  //17: Back down edge
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[2]);
  house.back().vertices.push_back(points[3]);
  house.back().vertices.push_back(points[11]);
  house.back().vertices.push_back(points[10]);
  
  //18: Right down edge
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[1]);
  house.back().vertices.push_back(points[3]);
  house.back().vertices.push_back(points[11]);
  house.back().vertices.push_back(points[9]);
  
  //19: Front left vertical edge
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[0]);
  house.back().vertices.push_back(points[4]);
  house.back().vertices.push_back(points[12]);
  house.back().vertices.push_back(points[8]);
  
  //20: Front right vertical edge
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[1]);
  house.back().vertices.push_back(points[5]);
  house.back().vertices.push_back(points[13]);
  house.back().vertices.push_back(points[9]);
  
  //21: Back right vertical edge
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[3]);
  house.back().vertices.push_back(points[7]);
  house.back().vertices.push_back(points[15]);
  house.back().vertices.push_back(points[11]);
  
  //22: Back left vertical edge
  materialOfFace.push_back(0);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[2]);
  house.back().vertices.push_back(points[6]);
  house.back().vertices.push_back(points[14]);
  house.back().vertices.push_back(points[10]);
  
  //23: Front top edge
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[4]);
  house.back().vertices.push_back(points[5]);
  house.back().vertices.push_back(points[13]);
  house.back().vertices.push_back(points[12]);
  
  //24: Left top edge
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[4]);
  house.back().vertices.push_back(points[6]);
  house.back().vertices.push_back(points[14]);
  house.back().vertices.push_back(points[12]);
  
  //25: Back top edge
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[6]);
  house.back().vertices.push_back(points[7]);
  house.back().vertices.push_back(points[15]);
  house.back().vertices.push_back(points[14]);
  
  //26: Right top edge
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[5]);
  house.back().vertices.push_back(points[7]);
  house.back().vertices.push_back(points[15]);
  house.back().vertices.push_back(points[13]);
  
  //27: Front left hip
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[4]);
  house.back().vertices.push_back(points[16]);
  house.back().vertices.push_back(points[12]);
  
  //28: Back left hip
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[6]);
  house.back().vertices.push_back(points[16]);
  house.back().vertices.push_back(points[14]);
  
  //29: Back right hip
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[7]);
  house.back().vertices.push_back(points[16]);
  house.back().vertices.push_back(points[15]);
  
  //30: Front right hip
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[5]);
  house.back().vertices.push_back(points[16]);
  house.back().vertices.push_back(points[13]);
  
  //31: Front ridge
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[4]);
  house.back().vertices.push_back(points[5]);
  house.back().vertices.push_back(points[16]);
  
  //32: Left ridge
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[4]);
  house.back().vertices.push_back(points[6]);
  house.back().vertices.push_back(points[16]);
  
  //33: Back ridge
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[6]);
  house.back().vertices.push_back(points[7]);
  house.back().vertices.push_back(points[16]);
  
  //34: Right ridge
  materialOfFace.push_back(1);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[5]);
  house.back().vertices.push_back(points[7]);
  house.back().vertices.push_back(points[16]);
  
  //35: Door in second house
  materialOfFace.push_back(2);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[17]);
  house.back().vertices.push_back(points[18]);
  house.back().vertices.push_back(points[19]);
  house.back().vertices.push_back(points[20]);
  
  //36: Door left edge collapses
  materialOfFace.push_back(2);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[0]);
  house.back().vertices.push_back(points[17]);
  house.back().vertices.push_back(points[18]);
  
  //37: Door top edge collapses
  materialOfFace.push_back(2);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[0]);
  house.back().vertices.push_back(points[18]);
  house.back().vertices.push_back(points[19]);
  
  //38: Door right edge collapses
  materialOfFace.push_back(2);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[0]);
  house.back().vertices.push_back(points[19]);
  house.back().vertices.push_back(points[20]);
  
  //39: Window
  materialOfFace.push_back(6);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[21]);
  house.back().vertices.push_back(points[22]);
  house.back().vertices.push_back(points[23]);
  house.back().vertices.push_back(points[24]);
  
  //40: Window left edge collapses
  materialOfFace.push_back(6);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[21]);
  house.back().vertices.push_back(points[22]);
  house.back().vertices.push_back(points[1]);
  
  //41: Window top edge collapses
  materialOfFace.push_back(6);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[22]);
  house.back().vertices.push_back(points[23]);
  house.back().vertices.push_back(points[1]);
  
  //42: Window right edge collapses
  materialOfFace.push_back(6);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[23]);
  house.back().vertices.push_back(points[24]);
  house.back().vertices.push_back(points[1]);
  
  //43: Window bottom edge collapses
  materialOfFace.push_back(6);
  house.push_back(Polygon_d());
  house.back().vertices.push_back(points[24]);
  house.back().vertices.push_back(points[21]);
  house.back().vertices.push_back(points[1]);
  
  std::vector<Mesh_d> houseRefined;
  for (unsigned int index = 0; index < house.size(); ++index) {
    houseRefined.push_back(refine(house[index], 0.125, 0.1));
//    houseRefined(triangulateQuad(house[index]));
    houseRefined.back().colour[0] = std::get<0>(materials[materialOfFace[index]]);
    houseRefined.back().colour[1] = std::get<1>(materials[materialOfFace[index]]);
    houseRefined.back().colour[2] = std::get<2>(materials[materialOfFace[index]]);
    houseRefined.back().colour[3] = 0.2;
  } faces = houseRefined;
  edges = generateEdges(house);
  vertices = generateVertices(house);
}
