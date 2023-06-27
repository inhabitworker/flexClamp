// Input Parameters

/* [ General ] */ 

// The print-in-place clearance, your printer configuration may be capable of less or more. Default 0.3mm is the typical choice.
    Clearance = 0.3; // [0 : 0.05 : 0.5]

/* [ Spring ] */

// The radius of the spring circle.
    Radius = 10;

// The overall thickness of the spring body. This will inform the radius of the revolute joints with plate.
    Thickness = 3;

// The number of layers interior to the spring. We would like the thickness of these to be more than the slicer wall thickness. 
    Layers = 2; // [0 : 1 : 100]

/* [ Plates ] */

// The width of the plates doubles as the depth of the spring, as their extent forms the first layer of printing.
    Width = 10;

// The length of a plate extending into the interior of the circle/spring. Limited by spring radius.
    InteriorLength = 5;
// The length of a plate as it extends outwards. Arbitrary.
    ExteriorLength = 5;

// Thickness of the plates. This informs the angle of our spring opening.
    PlateThickness = Thickness/1.5;

// The initial gap between the plate and the axis mirroring them (i.e. 2*this = gap between plates).
    Gap = 0.25;

// Extend the lips of the plate.
    PlateExtension = 3;

// [* Hidden *]
    $fs = 0.5;
    $fn = 40;
    Overlap = 0.1;

// I made this to use with an ADXL345 board. You may well not care an iota for this. lol
    ADXL345 = false;


// Computed Parameters
    InternalRadius = Radius - Thickness/2;

    CapRad = (Thickness/2)*1.25;
    HoleRad = CapRad - 2*Clearance;
    RodRad = HoleRad - Clearance;

    // Span of plate, gap etc.
    PlateToPoint = (Thickness/2 + PlateThickness/2 + Overlap + Gap);
    OpeningAngle = asin(PlateToPoint / InternalRadius);
    OpeningTerminalX = PlateToPoint;
    OpeningTerminalY = cos(OpeningAngle) * InternalRadius;

    OpeningR = [OpeningTerminalX, -OpeningTerminalY, 0];

    ChannelCut = 2*Width/3;

module Sector() {
    SectorX = sin(OpeningAngle) * 2 * Radius;
    SectorY = cos(OpeningAngle) * 2 * Radius;

    translate([0,0,- Width/2 - Overlap])
    linear_extrude(Width+ 2*Overlap) 
    polygon([
        [0,0], 
        [SectorX, -SectorY], 
        [-Radius-Overlap, -SectorY], 
        [-Radius-Overlap, Radius+Overlap],
        [-Overlap, Radius+Overlap]
        ], [[0,1,2,3,4]]);
}

module SpringLayering() {
    // Calculating amount based on frequency, then cutting the sector and
    // endcaps
    // Then not mirroring lol!
    
    // Need space for outer 2, plus extra lines n and n+1 spaces
    // we're really just drawing gaps to remove

    // if frequency is 1, solid, if two, a gap. if more, more layers.

    if(Layers == 0) {
    } else {
        // Endcap Cut
        difference() {
            // Halvening 
            difference() {
                union() {
                    LayerThickness = Thickness/(Layers-0.5);

                    for(i = [0 : 1 : Layers-2]) {
                        OuterRadius = Radius - i*LayerThickness-LayerThickness/2;
                        InnerRadius = Radius - ((i+1)*LayerThickness);

                        difference() {
                            cylinder(Width + Overlap, OuterRadius, OuterRadius, center=true);
                            cylinder(Width + 2*Overlap, InnerRadius, InnerRadius, center=true);
                        }
                    }
                }

                translate([-2*Radius-2*Overlap,-Radius,-Radius/2])
                cube(Radius*2);
            }

            translate(OpeningR)
            cylinder(Width + 3*Overlap, Thickness*0.75, Thickness*0.75, center=true);
        }
    }
}

module ChannelOpening() {
    CutTo = 3/4;
    CutWidth = 2*CapRad*CutTo;

    translate([OpeningTerminalX, -OpeningTerminalY,0])
    rotate(OpeningAngle)
    intersection() {
        ChannelRad = CapRad + 2*Overlap;

        cylinder(Width + 2*Overlap, ChannelRad, ChannelRad, center=true);

        translate([- ChannelRad , - ChannelRad/2 + Overlap,0])
        rotate([90,0,0])
        translate([0,0,-Thickness])
        linear_extrude(2*Thickness + 2*Overlap)
        polygon([
            [0, ChannelCut/2],
            [0, -ChannelCut/2],
            [CutWidth + 2 * Overlap, - ChannelCut/2 ],
            [CutWidth + 2 * Overlap , ChannelCut/2 - tan(35)*CutWidth],
        ],[[0,1,2,3]]); 
    }
}

module Spring() {
    union(){
        // Hole and layer gap cuts 
        difference() {
            // Opening Caps
            union() {
                // Opening Sector & Half Cut 
                difference() {
                    // Base Loop
                    difference() {
                        cylinder(Width, Radius, Radius , center = true);
                        cylinder(Width+1, Radius - Thickness, Radius - Thickness, center = true);
                    };

                    Sector();
                }

                translate(OpeningR)
                cylinder(Width, CapRad, CapRad, center=true);
            }

            translate(OpeningR) 
            cylinder(r=HoleRad, h=Width + 2 * Overlap, center=true);

            ChannelOpening();
            SpringLayering();
        }


        CapHat = Width/6 - 2*Clearance;

        translate(OpeningR) 
        translate([0,0,Width/2-CapHat])
        cylinder(CapHat , CapRad, CapRad);
    }
}
module Plate() {
    translate(OpeningR)
    // Add Rods
    union() {
            // Rod Connection
            union() {
                // Plate with ingress cut 
                difference() {
                    // Base Plate , translate to cut, keeping cylinder central
                    translate([-Thickness/2 - Overlap, 0, 0]) 
                    union() {
                        // Initial, with interior
                        cube([PlateThickness, 2*Thickness, Width], center=true);
                        // Extension
                        translate([-PlateThickness/2, - Thickness - PlateExtension, -Width/2]) 
                        cube([PlateThickness, PlateExtension, Width]);
                    }

                    translate([0, 0, -(Width+Overlap)/2]) 
                    union() {
                        cylinder(Width + Overlap, CapRad + Clearance, CapRad + Clearance);
                        translate([0,Radius/2, Width/2 + Overlap/2])
                        cube([2*CapRad + 2*Clearance, Radius, Width+Overlap], center=true);
                    }

                    // Chamfer Lip
                    translate([
                        -Thickness/2 - PlateThickness/2 - Overlap,
                        -Thickness - PlateExtension,
                        0])    
                    rotate(45)
                    cube([PlateThickness, PlateThickness, Width+Overlap], center=true);
                }

                // Connection to rod
                // rod matching ring, plate, circular cut
                // difference() {
                    //translate([-Thickness/2-2*Clearance,-2*RodRad,-ChannelCut/2+Clearance*1.5])
                    //cube([Thickness/2+2*Clearance, 4*RodRad, ChannelCut/2]);
                    translate([0,0,-ChannelCut/2 + Clearance])
                    linear_extrude(ChannelCut/2 - Clearance)
                    polygon([
                        [0,-RodRad],
                        [0, RodRad],
                        [-Thickness/2 - PlateThickness/2, RodRad],
                        [-Thickness/2 - PlateThickness/2, -2*RodRad]
                    ],[[0,1,2,3]]);
                //}
            }

        translate([0,0, - Width/12])
        cylinder(Width-Width/6, RodRad, RodRad, center=true);
    }
}
module Clamp() {
    union() {
        Spring();
        mirror([1,0,0])
        Spring();
    }

    Plate();
    mirror([1, 0, 0]) {
       Plate();
    }
} 

Clamp();

