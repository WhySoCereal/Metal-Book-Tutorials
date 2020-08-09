//////////  SETUP ////////////////

// See live views in assistant editor
import PlaygroundSupport
// Has customised view MTKView & convenient methods
import MetalKit

// Check for suitable GPU by creating a device
guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("GPU is not suppported")
}

// Set up the view
let frame = CGRect(x: 0, y: 0, width: 600, height: 600)
let view = MTKView(frame: frame, device: device) // View for rendering Metal Content
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)

/////////////// THE MODEL ///////////

// Model I/O - framework integrates with Metal and SceneKit

let allocator = MTKMeshBufferAllocator(device:device) // Manages the memory for the mesh data

// Create a sphere with the specified size and returns MDLMesh with all the vertex info in buffers
let mdlMesh = MDLMesh(sphereWithExtent: [0.2, 0.2, 0.2],
                      segments: [100, 100],
                      inwardNormals: false,
                      geometryType: .triangles,
                      allocator: allocator)
// Convert Model I/O mesh to MetalKit mesh for metal to use it
let mesh = try MTKMesh(mesh: mdlMesh, device: device)


///////////// QUEUES, BUFFERS AND ENCODERS ///////////////
// Create a command queue - organizes the command buffers - created once
guard let commandQueue = device.makeCommandQueue() else {
    fatalError("Could not create the command queue")
    
}

// Vertex function - vertex_main - manipulate vertex positions
// Fragment function - fragment_main - specify the pixel colour
let shader = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[ attribute(0) ]];
};

vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
    return vertex_in.position;
}
fragment float4 fragment_main() {
    return float4(0, 0.4, 0.21, 1);
}
"""

// Set up the Metal library
let library = try device.makeLibrary(source: shader, options: nil)
let vertexFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction = library.makeFunction(name: "fragment_main")

//////////// THE PIPELINE STATE /////////////////

// Set up a pipeline state for the GPU.
// Tells GPU nothing will change until the state changes - more efficient for GPU
// Contains all info GPU needs, i.e pixel format, depth toggle
// Descriptor holds everything the pipeline needs to know
// Sets up descriptor with correct shader functions and vertex descriptor
let descriptor = MTLRenderPipelineDescriptor()
descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
descriptor.vertexFunction = vertexFunction
descriptor.fragmentFunction = fragmentFunction
descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

// Create the pipeline state from the descriptor:
let pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
// Takes valuable processing time - should be one-time setup, but in reality can be many for multiple shaders

/////////////////// RENDERING ///////////////////////

// Rendering - simple - fill a static view
// Command buffer - stores all the commands that you ask the GPU to run
guard let commandBuffer = commandQueue.makeCommandBuffer(),
// descriptor holds data for a number of render destinations called attachments
    // each attachment needs information such as a texture to store to, and whether to keep the texture throughout the render pass.
    // the render pass descriptor is used to create the render command encoder.
let descriptor = view.currentRenderPassDescriptor,
// A render command encoder - holds all the information necessary to send to the GPU so that the GPU can draw the vertices.
let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
    else { fatalError() }

// Give the render encoder the pipeline state
renderEncoder.setRenderPipelineState(pipelineState)
// Give sphere mesh buffer to the render encoder, offset its position in buffer where vertex info starts, index is how the GPU vertex shader will locate this buffer.
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)

// Vertices only need to be rendered once since the sphere only has one submesh
guard let submesh = mesh.submeshes.first else {
    fatalError()
}

// Draw in Metal PogU!!!!
// GPU renders a vertex buffer consisting of triangles with the vertices placed in the correct order by the submesh index information
renderEncoder.drawIndexedPrimitives(type: .triangle,
                                    indexCount: submesh.indexCount,
                                    indexType: submesh.indexType,
                                    indexBuffer: submesh.indexBuffer.buffer,
                                    indexBufferOffset: 0)

// Complete sending the commands to the render command encoder and finalise the frame
// Tell the render command encoder there's no more draw calls
renderEncoder.endEncoding()
guard let drawable = view.currentDrawable else {
    fatalError()
}
// Get drawable from MTKView - backed by CAMetalLayer - owns a drawable texture which Metal can read and write to
commandBuffer.present(drawable)
// Ask command buffer to present the MTKView's drawable and commit to the GPU
commandBuffer.commit()

// Show the Metal view in the assistant editor
PlaygroundPage.current.liveView = view


//////////// SUMMARY //////////////
/*
 1. Initialise metal
        device: MTLDevice
        commandQueue: MTLCommandQueue
 
 2. Load a model
        mesh: MTLMesh
 
 3. Set up the pipeline
        Vertex function
        Fragment function
 
 4. Render
        commandBuffer: MTLCommandBuffer
        renderEncoder: MTLRenderCommandEncoder
 */
